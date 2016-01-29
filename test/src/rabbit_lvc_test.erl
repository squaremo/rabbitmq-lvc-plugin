%% The contents of this file are subject to the Mozilla Public License
%% Version 1.1 (the "License"); you may not use this file except in
%% compliance with the License. You may obtain a copy of the License
%% at http://www.mozilla.org/MPL/
%%
%% Software distributed under the License is distributed on an "AS IS"
%% basis, WITHOUT WARRANTY OF ANY KIND, either express or implied. See
%% the License for the specific language governing rights and
%% limitations under the License.
%%
%% The Original Code is RabbitMQ.
%%
%% The Initial Developer of the Original Code is VMware, Inc.
%% Copyright (c) 2007-2012 VMware, Inc.  All rights reserved.
%%

-module(rabbit_lvc_test).

-include_lib("eunit/include/eunit.hrl").
-include_lib("amqp_client/include/amqp_client.hrl").

lvc_test() ->
    {ok, Conn} = amqp_connection:start(#amqp_params_network{}),
    {ok, Ch} = amqp_connection:open_channel(
                 Conn, {amqp_direct_consumer, [self()]}),
    X = <<"test-lvc-exchange">>,
    RK = <<"test">>,
    Payload = <<"Hello world">>,
    exchange_declare(Ch, X),
    Q1 = queue_declare(Ch),
    Q2 = queue_declare(Ch),
    bind(Ch, X, RK, Q1),
    publish(Ch, X, RK, Payload),
    bind(Ch, X, RK, Q2),
    expect(Ch, Q1, Payload),
    expect(Ch, Q2, Payload),
    amqp_connection:close(Conn).

lvc_e2e_test() ->
    {ok, Conn} = amqp_connection:start(#amqp_params_network{}),
    {ok, Ch} = amqp_connection:open_channel(
                 Conn, {amqp_direct_consumer, [self()]}),
    LvcExchange = <<"test-lvc-exchange">>,
    RK = <<"key1">>,
    Payload = <<"Hello world">>,
    exchange_declare(Ch, LvcExchange),
    Exchange = <<"test-exchange">>,
    exchange_declare(Ch, Exchange, <<"fanout">>),
    Q1 = queue_declare(Ch),
    Q2 = queue_declare(Ch),
    bind(Ch, Exchange, <<"">>, Q1),
    bind(Ch, Exchange, <<"">>, Q2),
    publish(Ch, LvcExchange, RK, Payload),
    exchange_bind(Ch, Exchange, RK, LvcExchange),
    expect(Ch, Q1, Payload),
    expect(Ch, Q2, Payload),
    amqp_connection:close(Conn).

exchange_declare(Ch, X) ->
    amqp_channel:call(Ch, #'exchange.declare'{exchange    = X,
                                              type        = <<"x-lvc">>,
                                              auto_delete = true}).

exchange_declare(Ch, X, Type) ->
    amqp_channel:call(Ch, #'exchange.declare'{exchange    = X,
                                              type        = Type,
                                              auto_delete = true}).

queue_declare(Ch) ->
    #'queue.declare_ok'{queue = Q} =
        amqp_channel:call(Ch, #'queue.declare'{exclusive = true}),
    Q.

publish(Ch, X, RK, Payload) ->
    amqp_channel:cast(Ch, #'basic.publish'{exchange    = X,
                                           routing_key = RK},
                      #amqp_msg{payload = Payload}).

expect(Ch, Q, Payload) ->
    #'basic.consume_ok'{consumer_tag = CTag} =
        amqp_channel:call(Ch, #'basic.consume'{queue = Q}),
    receive
        {#'basic.deliver'{consumer_tag = CTag}, #amqp_msg{payload = Payload}} ->
            ok
    end.

bind(Ch, X, RK, Q) ->
    amqp_channel:call(Ch, #'queue.bind'{queue       = Q,
                                        exchange    = X,
                                        routing_key = RK}).

exchange_bind(Ch, D, RK, S) ->
    amqp_channel:call(Ch, #'exchange.bind'{source       = S,
                                           destination  = D,
                                           routing_key  = RK}).
