-define(LVC_TABLE, lvc).

-record(cachekey, {exchange, routing_key}).
-record(cached, {key, content}).
