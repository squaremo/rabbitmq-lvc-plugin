-module(rabbit_exchange_type_lvc).
-include_lib("rabbit_common/include/rabbit.hrl").
-include("rabbit_lvc_plugin.hrl").

-behaviour(rabbit_exchange_type).

-export([description/0, serialise_events/0, route/2]).
-export([validate/1, validate_binding/2,
         create/2, recover/2, delete/3, policy_changed/2,
         add_binding/3, remove_bindings/3, assert_args_equivalence/2]).
-export([info/1, info/2]).

info(_X) -> [].
info(_X, _) -> [].

description() ->
    [{name, <<"x-lvc">>},
     {description, <<"Last-value cache exchange.">>}].

serialise_events() -> false.

route(Exchange = #exchange{name = Name},
      Delivery = #delivery{message = Msg}) ->
    #basic_message{routing_keys = RKs} = Msg,
    Keys = case RKs of
               CC when is_list(CC) -> CC;
               To                 -> [To]
           end,
    rabbit_misc:execute_mnesia_transaction(
      fun () ->
              [mnesia:write(?LVC_TABLE,
                            #cached{key = #cachekey{exchange=Name,
                                                    routing_key=K},
                                    content = Msg},
                            write) ||
                  K <- Keys]
      end),
    rabbit_exchange_type_direct:route(Exchange, Delivery).

validate(_X) -> ok.
validate_binding(_X, _B) -> ok.
create(_Tx, _X) -> ok.
recover(_X, _Bs) -> ok.

delete(transaction, #exchange{ name = Name }, _Bs) ->
    [mnesia:delete(?LVC_TABLE, K, write) ||
        #cached{ key = K } <-
            mnesia:match_object(?LVC_TABLE,
                                #cached{key = #cachekey{
                                          exchange = Name, _ = '_' },
                                        _ = '_'}, write)],
    ok;
delete(_Tx, _X, _Bs) ->
	ok.

policy_changed(_X1, _X2) -> ok.

add_binding(none, #exchange{ name = XName },
            #binding{ key = RoutingKey,
                      destination = QueueName }) ->
    case rabbit_amqqueue:lookup(QueueName) of
        {error, not_found} ->
            rabbit_misc:protocol_error(
              internal_error,
              "could not find queue '~s'",
              [QueueName]);
        {ok, Q = #amqqueue{}} ->
            case mnesia:dirty_read(
                   ?LVC_TABLE,
                   #cachekey{ exchange=XName,
                             routing_key=RoutingKey }) of
                [] ->
                    ok;
                [#cached{content = Msg}] ->
                    rabbit_amqqueue:deliver(
                      [Q], rabbit_basic:delivery(false, false, Msg, undefined))
            end
    end,
    ok;
add_binding(_Tx, _X, _B) ->
    ok.

remove_bindings(_Tx, _X, _Bs) -> ok.

assert_args_equivalence(X, Args) ->
    rabbit_exchange_type_direct:assert_args_equivalence(X, Args).
