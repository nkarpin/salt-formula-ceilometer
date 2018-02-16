{%- from "ceilometer/map.jinja" import agent with context %}
{%- if agent.enabled %}

ceilometer_agent_packages:
  pkg.installed:
  - names: {{ agent.pkgs }}

ceilometer_agent_conf:
  file.managed:
  - name: /etc/ceilometer/ceilometer.conf
  - source: salt://ceilometer/files/{{ agent.version }}/ceilometer-agent.conf.{{ grains.os_family }}
  - template: jinja
  - require:
    - pkg: ceilometer_agent_packages

{% for service_name in agent.services %}
{{ service_name }}_default:
  file.managed:
    - name: /etc/default/{{ service_name }}
    - source: salt://ceilometer/files/default
    - template: jinja
    - require:
      - pkg: ceilometer_agent_packages
    - defaults:
        service_name: {{ service_name }}
        values: {{ agent }}
    - watch_in:
      - service: ceilometer_agent_services
{% endfor %}

{% if agent.logging.log_appender -%}

{%- if agent.logging.log_handlers.get('fluentd', {}).get('enabled', False) %}
ceilometer_agent_fluentd_logger_package:
  pkg.installed:
    - name: python-fluent-logger
{%- endif %}

{% for service_name in agent.services %}
{{ service_name }}_logging_conf:
  file.managed:
    - name: /etc/ceilometer/logging/logging-{{ service_name }}.conf
    - source: salt://ceilometer/files/logging.conf
    - template: jinja
    - user: ceilometer
    - group: ceilometer
    - require:
      - pkg: ceilometer_agent_packages
{%- if agent.logging.log_handlers.get('fluentd', {}).get('enabled', False) %}
      - pkg: ceilometer_agent_fluentd_logger_package
{%- endif %}
    - makedirs: True
    - defaults:
        service_name: {{ service_name }}
        values: {{ agent }}
    - watch_in:
      - service: ceilometer_agent_services
{% endfor %}

{% endif %}

{%- for publisher_name, publisher in agent.get('publisher', {}).items() %}

{%- if publisher_name not in ["default", "gnocchi"] %}

ceilometer_publisher_{{ publisher_name }}_pkg:
  pkg.latest:
    - name: ceilometer-publisher-{{ publisher_name }}

{%- endif %}

{%- endfor %}

ceilometer_agent_pipeline:
  file.managed:
  - name: /etc/ceilometer/pipeline.yaml
  - source: salt://ceilometer/files/{{ agent.version }}/pipeline.yaml
  - template: jinja
  - require:
    - pkg: ceilometer_agent_packages

{%- if agent.version != "kilo" %}

ceilometer_agent_event_pipeline:
  file.managed:
  - name: /etc/ceilometer/event_pipeline.yaml
  - source: salt://ceilometer/files/{{ agent.version }}/event_pipeline.yaml
  - template: jinja
  - require:
    - pkg: ceilometer_agent_packages
  - watch_in:
    - service: ceilometer_agent_services

{%- endif %}

ceilometer_agent_services:
  service.running:
  - names: {{ agent.services }}
  {%- if grains.get('noservices') %}
  - onlyif: /bin/false
  {%- endif %}
  - enable: true
  - watch:
    - file: ceilometer_agent_conf
    - file: ceilometer_agent_pipeline
{%- if agent.version != "kilo" %}
    - file: ceilometer_agent_event_pipeline
{%- endif %}

{%- endif %}
