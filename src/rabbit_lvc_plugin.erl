-module(rabbit_lvc_plugin).

-include("rabbit_lvc_plugin.hrl").

-export([setup_schema/0, disable_plugin/0]).

-rabbit_boot_step({?MODULE,
                   [{description, "last-value cache exchange type"},
                    {mfa, {rabbit_lvc_plugin, setup_schema, []}},
                    {mfa, {rabbit_registry, register, [exchange, <<"x-lvc">>, rabbit_exchange_type_lvc]}},
                    {cleanup, {?MODULE, disable_plugin, []}},
                    {requires, rabbit_registry},
                    {enables, recovery}]}).

%% private

setup_schema() ->
    mnesia:create_table(?LVC_TABLE,
                        [{attributes, record_info(fields, cached)},
                         {record_name, cached},
                         {type, set},
                         {disc_copies, [node()]}]),
    mnesia:wait_for_tables([?LVC_TABLE], 30000),
    ok.


disable_plugin() ->
    rabbit_registry:unregister(exchange, <<"x-lvc">>),
    mnesia:delete_table(?LVC_TABLE),
    ok.
