ceilometer:
  agent:
    polling_interval: 50
    cpu_polling_interval: 70
    disk_polling_interval: 80
    network_polling_interval: 90
    debug: true
    #region: RegionOne
    enabled: true
    version: liberty
    secret: password
    publisher:
      default:
      gnocchi:
        archive_policy: medium
        filter_project: service
    identity:
      engine: keystone
      host: 127.0.0.1
      port: 35357
      tenant: service
      user: ceilometer
      password: password
      endpoint_type: internalURL
    message_queue:
      engine: rabbitmq
      host: 127.0.0.1
      port: 5672
      user: openstack
      password: password
      virtual_host: '/openstack'
      # Workaround for https://bugs.launchpad.net/ceilometer/+bug/1337715
      rpc_thread_pool_size: 5
