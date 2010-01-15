{application, rabbit_lvc_plugin,
 [{description, "RabbitMQ last-value cache exchange plugin"},
  {vsn, "0.01"},
  {modules, [
    rabbit_lvc_plugin,
    rabbit_lvc_plugin_sup,
    rabbit_exchange_type_lvc
  ]},
  {registered, []},
  {mod, {rabbit_lvc_plugin, []}},
  {env, []},
  {applications, [kernel, stdlib, rabbit, mnesia]}]}.
