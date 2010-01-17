-module(rabbit_exchange_type_lvc).
-include_lib("../rabbitmq-server/include/rabbit.hrl").
-include("rabbit_lvc_plugin.hrl").

-behaviour(rabbit_exchange_behaviour).

-rabbit_boot_step({?MODULE,
                   [{mfa, {rabbit_exchange_type, register, [<<"x-lvc">>, ?MODULE]}},
                    {post, rabbit_exchange_type},
                    {pre, exchange_recovery}]}).

-export([description/0, publish/2]).
-export([validate/1, recover/2, create/1, delete/2, add_binding/2, delete_binding/2]).

description() ->
    {{name, <<"lvc">>},
     {description, <<"Last-value cache exchange.">>}}.

publish(Exchange = #exchange{name = Name},
        Delivery = #delivery{message = #basic_message{
                               routing_key = RK,
                               content = Content
                              }}) ->
    rabbit_misc:execute_mnesia_transaction(
      fun () -> 
              ok = mnesia:write(?LVC_TABLE,
                                #cached{key = #cachekey{exchange=Name, routing_key=RK},
                                        content = Content},
                                write)
      end),
    rabbit_exchange_type_direct:publish(Exchange, Delivery).

%% TODO in recover, init, delete: manage entries for a table

validate(_X) -> ok.

recover(X, _Bs) -> create(X).

create(_X) -> ok.

delete(_X, __Bs) -> ok.

add_binding(#exchange{ name = XName },
            #binding{ key = RoutingKey,
                      queue_name = QueueName }) ->
    %io:format("LVC bind ~p to ~p", [XName, RoutingKey]),
    case mnesia:dirty_read(
           ?LVC_TABLE,
           #cachekey{exchange=XName, routing_key=RoutingKey}) of
        [] -> ok;
        [#cached{content = Content}] ->
            case rabbit_amqqueue:lookup(QueueName) of
                {error, not_found} -> 
                    rabbit_misc:protocol_error(
                      internal_error,
                      "could not find queue '~s'",
                      [RoutingKey]);
                {ok, #amqqueue{ pid = Q }} ->
                    %io:format("LVC deliver-on-bind '~s'", [RoutingKey]),
                    rabbit_amqqueue:deliver(
                      Q,
                      rabbit_basic:delivery(
                        %% use mandatory so that the queue responds
                        true, false, none,
                        #basic_message{
                          content = Content,
                          exchange_name = XName,
                          routing_key = RoutingKey
                         }))
            end
    end,
    ok.

delete_binding(_X, _B) -> ok.
