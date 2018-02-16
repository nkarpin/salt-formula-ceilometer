{%- from "ceilometer/map.jinja" import server with context %}
{%- if server.enabled %}

ceilometer_server_packages:
  pkg.installed:
  - names: {{ server.pkgs }}

ceilometer_server_conf:
  file.managed:
  - name: /etc/ceilometer/ceilometer.conf
  - source: salt://ceilometer/files/{{ server.version }}/ceilometer-server.conf.{{ grains.os_family }}
  - template: jinja
  - require:
    - pkg: ceilometer_server_packages

{%- for service_name in server.services %}
{{ service_name }}_default:
  file.managed:
    - name: /etc/default/{{ service_name }}
    - source: salt://ceilometer/files/default
    - template: jinja
    - require:
      - pkg: ceilometer_server_packages
    - defaults:
        service_name: {{ service_name }}
        values: {{ server }}
    - watch_in:
      - service: ceilometer_server_services
{%- endfor %}

{%- if server.logging.log_appender %}

{%- if server.logging.log_handlers.get('fluentd', {}).get('enabled', False) %}
ceilometer_server_fluentd_logger_package:
  pkg.installed:
    - name: python-fluent-logger
{%- endif %}

ceilometer_general_logging_conf:
  file.managed:
    - name: /etc/ceilometer/logging.conf
    - source: salt://ceilometer/files/logging.conf
    - template: jinja
    - user: ceilometer
    - group: ceilometer
    - require:
      - pkg: ceilometer_server_packages
{%- if server.logging.log_handlers.get('fluentd', {}).get('enabled', False) %}
      - pkg: ceilometer_server_fluentd_logger_package
{%- endif %}
    - defaults:
        service_name: ceilometer
        values: {{ server }}
    - watch_in:
      - service: ceilometer_server_services
{%- if server.version not in ['liberty', 'juno', 'kilo', 'mitaka'] %}
      - service: ceilometer_apache_restart
{%- endif %}

/var/log/ceilometer/ceilometer.log:
  file.managed:
    - user: ceilometer
    - group: ceilometer
    - watch_in:
      - service: ceilometer_server_services
{%- if server.version not in ['liberty', 'juno', 'kilo', 'mitaka'] %}
      - service: ceilometer_apache_restart
{%- endif %}

{%- for service_name in server.get('services', []) %}
{{ service_name }}_logging_conf:
  file.managed:
    - name: /etc/ceilometer/logging/logging-{{ service_name }}.conf
    - source: salt://ceilometer/files/logging.conf
    - template: jinja
    - require:
      - pkg: ceilometer_server_packages
{%- if server.logging.log_handlers.get('fluentd', {}).get('enabled', False) %}
      - pkg: ceilometer_server_fluentd_logger_package
{%- endif %}
    - makedirs: True
    - defaults:
        service_name: {{ service_name }}
        values: {{ server }}
    - watch_in:
      - service: ceilometer_server_services
{%- endfor %}

{%- endif %}

{%- for name, rule in server.get('policy', {}).items() %}

{%- if rule != None %}
rule_{{ name }}_present:
  keystone_policy.rule_present:
  - path: /etc/ceilometer/policy.json
  - name: {{ name }}
  - rule: {{ rule }}
  - require:
    - pkg: ceilometer_server_packages

{%- else %}

rule_{{ name }}_absent:
  keystone_policy.rule_absent:
  - path: /etc/ceilometer/policy.json
  - name: {{ name }}
  - require:
    - pkg: ceilometer_server_packages

{%- endif %}

{%- endfor %}

{%- for publisher_name, publisher in server.get('publisher', {}).items() %}

{%- if publisher_name not in ["default", "gnocchi", "panko"] %}

ceilometer_publisher_{{ publisher_name }}_pkg:
  pkg.latest:
    - name: ceilometer-publisher-{{ publisher_name }}

{%- endif %}

{%- endfor %}

ceilometer_server_pipeline:
  file.managed:
  - name: /etc/ceilometer/pipeline.yaml
  - source: salt://ceilometer/files/{{ server.version }}/pipeline.yaml
  - template: jinja
  - require:
    - pkg: ceilometer_server_packages

{%- if server.version != "kilo" %}

ceilometer_server_event_pipeline:
  file.managed:
  - name: /etc/ceilometer/event_pipeline.yaml
  - source: salt://ceilometer/files/{{ server.version }}/event_pipeline.yaml
  - template: jinja
  - require:
    - pkg: ceilometer_server_packages
  - watch_in:
    - service: ceilometer_server_services

ceilometer_server_event_definitions:
  file.managed:
  - name: /etc/ceilometer/event_definitions.yaml
  - source: salt://ceilometer/files/{{ server.version }}/event_definitions.yaml
  - template: jinja
  - require:
    - pkg: ceilometer_server_packages
  - watch_in:
    - service: ceilometer_server_services

ceilometer_server_gabbi_pipeline:
  file.managed:
  - name: /etc/ceilometer/gabbi_pipeline.yaml
  - source: salt://ceilometer/files/{{ server.version }}/gabbi_pipeline.yaml
  - template: jinja
  - require:
    - pkg: ceilometer_server_packages
  - watch_in:
    - service: ceilometer_server_services

{%- endif %}

# for Newton and newer
{%- if server.version not in ['liberty', 'juno', 'kilo', 'mitaka'] %}

ceilometer_api_apache_config:
  file.managed:
  {%- if server.version == 'newton' %}
  - name: /etc/apache2/sites-available/ceilometer.conf
  {%- else %}
  - name: /etc/apache2/sites-available/ceilometer-api.conf
  {%- endif %}
  - source: salt://ceilometer/files/{{ server.version }}/ceilometer.apache2.conf.Debian
  - template: jinja
  - require:
    - pkg: ceilometer_server_packages

ceilometer_api_config:
  file.symlink:
     {%- if server.version == 'newton' %}
     - name: /etc/apache2/sites-enabled/ceilometer.conf
     - target: /etc/apache2/sites-available/ceilometer.conf
     {%- else %}
     - name: /etc/apache2/sites-enabled/ceilometer-api.conf
     - target: /etc/apache2/sites-available/ceilometer-api.conf
     {%- endif %}

ceilometer_apache_restart:
  service.running:
  - name: apache2
  - enable: true
  {%- if grains.get('noservices') %}
  - onlyif: /bin/false
  {%- endif %}
  - watch:
    - file: ceilometer_server_conf
    - file: ceilometer_api_config
    - file: ceilometer_server_event_definitions
    - file: ceilometer_server_event_pipeline
    - file: ceilometer_server_gabbi_pipeline
    - file: ceilometer_server_pipeline

{%- endif %}

ceilometer_server_services:
  service.running:
  - names: {{ server.services }}
  - enable: true
  {%- if grains.get('noservices') %}
  - onlyif: /bin/false
  {%- endif %}
  - watch:
    - file: ceilometer_server_conf

{%- endif %}
