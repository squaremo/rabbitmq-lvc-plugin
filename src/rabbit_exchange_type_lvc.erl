-module(rabbit_exchange_type_lvc).
-include_lib("rabbit_common/include/rabbit.hrl").
-include("rabbit_lvc_plugin.hrl").

-behaviour(rabbit_exchange_type).

-export([description/0, route/2]).
-export([validate/1, create/2, recover/2, delete/3,
         add_binding/3, remove_bindings/3, assert_args_equivalence/2]).

-define(TX, false).

-include_lib("rabbit_common/include/rabbit_exchange_type_spec.hrl").

description() ->
    [{name, <<"lvc">>},
     {description, <<"Last-value cache exchange.">>}].

route(Exchange = #exchange{name = Name},
      Delivery = #delivery{message = #basic_message{
                             routing_key = RK,
                             content = Content
                            }}) ->
    Keys = case RK of
               CC when is_list(CC) -> CC;
               To                 -> [To]
           end,
    rabbit_misc:execute_mnesia_transaction(
      fun () ->
              [mnesia:write(?LVC_TABLE,
                            #cached{key = #cachekey{exchange=Name,
                                                    routing_key=K},
                                    content = Content},
                            write) ||
                  K <- Keys]
      end),
    rabbit_exchange_type_direct:route(Exchange, Delivery).

validate(_X) -> ok.
create(_Tx, _X) -> ok.
recover(_X, _Bs) -> ok.

delete(?TX, #exchange{ name = Name }, _Bs) ->
    rabbit_misc:execute_mnesia_transaction(
      fun() ->
              [mnesia:delete(?LVC_TABLE, K, write) ||
                  #cached{ key = K } <-
                     mnesia:match_object(?LVC_TABLE,
                                          #cached{key = #cachekey{
                                                    exchange = Name, _ = '_' },
                                                  _ = '_'}, write)]
      end),
	ok;
delete(_Tx, _X, _Bs) ->
	ok.


add_binding(?TX, #exchange{ name = XName },
            #binding{ key = RoutingKey,
                      destination = QueueName }) ->
    case rabbit_amqqueue:lookup(QueueName) of
        {error, not_found} ->
            rabbit_misc:protocol_error(
              internal_error,
              "could not find queue '~s'",
              [QueueName]);
        {ok, #amqqueue{ pid = Q }} ->
            %% RabbitMQ doesn't support multiple binding keys YET
            Keys = case RoutingKey of
                       CC when is_list(CC) -> CC;
                       To                 -> [To]
                   end,
            Values = lists:foldl(
                       fun (Key, Msgs) ->
                               case mnesia:dirty_read(
                                      ?LVC_TABLE,
                                      #cachekey{exchange=XName,
                                                routing_key=Key}) of
                                   [] ->
                                       Msgs;
                                   [#cached{content = Content}] ->
                                       {Props, Payload} =
                                           rabbit_basic:from_content(Content),
                                       [rabbit_basic:message(
                                          XName, Key, Props, Payload) | Msgs]
                               end
                       end,
                       [], Keys),
            [rabbit_amqqueue:deliver(
               Q, rabbit_basic:delivery(false, false, none, V, undefined)) ||
                V <- Values]
    end,
    ok;
add_binding(_Tx, _X, _B) ->
    ok.

remove_bindings(_Tx, _X, _Bs) -> ok.

assert_args_equivalence(X, Args) ->
    rabbit_exchange_type_direct:assert_args_equivalence(X, Args).
