# Firewall management module
{%- if salt['pillar.get']('firewall:enabled') %}
  {% set firewall = salt['pillar.get']('firewall', {}) %}
  {% set install = firewall.get('install', False) %}
  {% set strict_mode = firewall.get('strict', False) %}
  {% set ipv6 = firewall.get('ipv6', False) %}
  {% set icmp = firewall.get('icmp', False) %}
  {% set icmpv6 = firewall.get('icmpv6', False) %}
  {% set global_block_nomatch = firewall.get('block_nomatch', False) %}
  {% set packages = salt['grains.filter_by']({
    'Debian': ['iptables', 'iptables-persistent'],
    'RedHat': ['iptables'],
    'default': 'Debian'}) %}

    {%- if install %}
      # Install required packages for firewalling      
      iptables_packages:
        pkg.installed:
          - pkgs:
            {%- for pkg in packages %}
            - {{pkg}}
            {%- endfor %}
    {%- endif %}

    {%- if strict_mode %}
      # If the firewall is set to strict mode, we'll need to allow some 
      # that always need access to anything
      iptables_allow_localhost:
        iptables.append:
          - table: filter
          - chain: INPUT
          - jump: ACCEPT
          - source: 127.0.0.1
          - save: True
      {%- if ipv6 %}
      iptables_allow_localhost_ipv6:
        iptables.append:
          - table: filter
          - chain: INPUT
          - jump: ACCEPT
          - source: ::1
          - family: ipv6
          - save: True
      {%- endif %}

      # Allow related/established sessions
      iptables_allow_established:
        iptables.append:
          - table: filter
          - chain: INPUT
          - jump: ACCEPT
          - match: conntrack
          - ctstate: 'RELATED,ESTABLISHED'
          - save: True            
      {%- if ipv6 %}
      iptables_allow_established_ipv6:
        iptables.append:
          - table: filter
          - chain: INPUT
          - jump: ACCEPT
          - match: conntrack
          - ctstate: 'RELATED,ESTABLISHED'
          - family: ipv6
          - save: True    
      {%- endif %}

      # Set the policy to deny everything unless defined
      enable_reject_policy:
        iptables.set_policy:
          - table: filter
          - chain: INPUT
          - policy: DROP
          - require:
            - iptables: iptables_allow_localhost
            - iptables: iptables_allow_established
      {%- if ipv6 %}
      enable_reject_policy_ipv6:
        iptables.set_policy:
          - table: filter
          - chain: INPUT
          - policy: DROP
          - family: ipv6
          - require:
            - iptables: iptables_allow_localhost_ipv6
            - iptables: iptables_allow_established_ipv6
      {%- endif %}
    {%- endif %}

    # Allowing icmp if needed
    {%- if icmp %}
      iptables_allow_icmp:
        iptables.append:
          - table: filter
          - chain: INPUT
          - jump: ACCEPT
          - proto: icmp
          - save: True
    {%- endif %}
    # Allowing icmp if needed
    {%- if icmpv6 and ipv6 %}
      iptables_allow_icmpv6:
        iptables.append:
          - table: filter
          - chain: INPUT
          - jump: ACCEPT
          - proto: icmpv6
          - family: ipv6
          - save: True
    {%- endif %}



  # Generate ipsets for all services that we have information about
  {%- for service_name, service_details in firewall.get('services', {}).items() %}  
    {% set block_nomatch = service_details.get('block_nomatch', False) %}
    {% set interfaces = service_details.get('interfaces','') %}
    {% set protos = service_details.get('protos',['tcp']) %}
    {% if service_details.get('comment', False) %}
      {% set comment = '- comment: ' + service_details.get('comment') %}
    {% else %}
      {% set comment = '' %}
    {% endif %}

    # Allow rules for ips/subnets
    {%- for ip in service_details.get('ips_allow', []) %}
      {%- if interfaces == '' %}
        {%- for proto in protos %}
      iptables_{{service_name}}_allow_{{ip}}_{{proto}}:
        iptables.append:
          - table: filter
          - chain: INPUT
          - jump: ACCEPT
          - source: {{ ip }}
          - dport: {{ service_name }}
          - proto: {{ proto }}
          - save: True
          {{ comment }}
        {%- endfor %}
      {%- else %}
        {%- for interface in interfaces %}
          {%- for proto in protos %}
      iptables_{{service_name}}_allow_{{ip}}_{{proto}}_{{interface}}:
        iptables.append:
          - table: filter
          - chain: INPUT
          - jump: ACCEPT
          - i: {{ interface }}
          - source: {{ ip }}
          - dport: {{ service_name }}
          - proto: {{ proto }}
          - save: True
          {{ comment }}
          {%- endfor %}
        {%- endfor %}
      {%- endif %}
    {%- endfor %}

    {%- if not strict_mode and global_block_nomatch or block_nomatch %}
      # If strict mode is disabled we may want to block anything else
      {%- if interfaces == '' %}
        {%- for proto in protos %}
      iptables_{{service_name}}_deny_other_{{proto}}:
        iptables.append:
          - position: last
          - table: filter
          - chain: INPUT
          - jump: REJECT
          - dport: {{ service_name }}
          - proto: {{ proto }}
          - save: True
          {{ comment }}
        {%- endfor %}
      {%- else %}
        {%- for interface in interfaces %}
          {%- for proto in protos %}
      iptables_{{service_name}}_deny_other_{{proto}}_{{interface}}:
        iptables.append:
          - position: last
          - table: filter
          - chain: INPUT
          - jump: REJECT
          - i: {{ interface }}
          - dport: {{ service_name }}
          - proto: {{ proto }}
          - save: True
          {{ comment }}
          {%- endfor %}
        {%- endfor %}
      {%- endif %}

    {%- endif %}    

  {%- endfor %}

  # Generate ipsets for all services that we have information about for ipv6
  {%- if ipv6 %} 
  {%- for service_name, service_details in firewall.get('services_ipv6', {}).items() %}  
    {% set block_nomatch = service_details.get('block_nomatch', False) %}
    {% set interfaces = service_details.get('interfaces','') %}
    {% set protos = service_details.get('protos',['tcp']) %}
    {% if service_details.get('comment', False) %}
      {% set comment = '- comment: ' + service_details.get('comment') %}
    {% else %}
      {% set comment = '' %}
    {% endif %}

    # Allow rules for ips/subnets
    {%- for ip in service_details.get('ips_allow', []) %}
      {%- if interfaces == '' %}
        {%- for proto in protos %}
      iptables_{{service_name}}_allow_{{ip}}_{{proto}}:
        iptables.append:
          - table: filter
          - chain: INPUT
          - jump: ACCEPT
          - source: {{ ip }}
          - dport: {{ service_name }}
          - proto: {{ proto }}
          - family: ipv6
          - save: True
          {{ comment }}
        {%- endfor %}
      {%- else %}
        {%- for interface in interfaces %}
          {%- for proto in protos %}
      iptables_{{service_name}}_allow_{{ip}}_{{proto}}_{{interface}}:
        iptables.append:
          - table: filter
          - chain: INPUT
          - jump: ACCEPT
          - i: {{ interface }}
          - source: {{ ip }}
          - dport: {{ service_name }}
          - proto: {{ proto }}
          - family: ipv6
          - save: True
          {{ comment }}
          {%- endfor %}
        {%- endfor %}
      {%- endif %}
    {%- endfor %}

    {%- if not strict_mode and global_block_nomatch or block_nomatch %}
      # If strict mode is disabled we may want to block anything else
      {%- if interfaces == '' %}
        {%- for proto in protos %}
      iptables_{{service_name}}_deny_other_{{proto}}:
        iptables.append:
          - position: last
          - table: filter
          - chain: INPUT
          - jump: REJECT
          - dport: {{ service_name }}
          - proto: {{ proto }}
          - family: ipv6
          - save: True
          {{ comment }}
        {%- endfor %}
      {%- else %}
        {%- for interface in interfaces %}
          {%- for proto in protos %}
      iptables_{{service_name}}_deny_other_{{proto}}_{{interface}}:
        iptables.append:
          - position: last
          - table: filter
          - chain: INPUT
          - jump: REJECT
          - i: {{ interface }}
          - dport: {{ service_name }}
          - proto: {{ proto }}
          - family: ipv6
          - save: True
          {{ comment }}
          {%- endfor %}
        {%- endfor %}
      {%- endif %}

    {%- endif %}    

  {%- endfor %}
  {%- endif %} 

  # Generate rules for NAT
  {%- for service_name, service_details in firewall.get('nat', {}).items() %}  
    {%- for ip_s, ip_ds in service_details.get('rules', {}).items() %}
      {%- for ip_d in ip_ds %}
      iptables_{{service_name}}_allow_{{ip_s}}_{{ip_d}}:
        iptables.append:
          - table: nat 
          - chain: POSTROUTING 
          - jump: MASQUERADE
          - o: {{ service_name }} 
          - source: {{ ip_s }}
          - destination: {{ ip_d }}
          - save: True
      {%- endfor %}
    {%- endfor %}
  {%- endfor %}

  # Generate rules for whitelisting IP classes
  {%- for service_name, service_details in firewall.get('whitelist', {}).items() %}
    {%- for ip in service_details.get('ips_allow', []) %}
      iptables_{{service_name}}_allow_{{ip}}:
        iptables.append:
           - table: filter
           - chain: INPUT
           - jump: ACCEPT
           - source: {{ ip }}
           - save: True
    {%- endfor %}
  {%- endfor %}

  # Generate rules for whitelisting IP classes with ipv6
  {%- if ipv6 %} 
  {%- for service_name, service_details in firewall.get('whitelist_ipv6', {}).items() %}
    {%- for ip in service_details.get('ips_allow', []) %}
      iptables_{{service_name}}_allow_{{ip}}_ipv6:
        iptables.append:
           - table: filter
           - chain: INPUT
           - jump: ACCEPT
           - source: {{ ip }}
           - family: ipv6
           - save: True
    {%- endfor %}
  {%- endfor %}
  {%- endif %}

{%- endif %}
