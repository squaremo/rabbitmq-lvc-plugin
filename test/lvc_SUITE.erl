%% This Source Code Form is subject to the terms of the Mozilla Public
%% License, v. 2.0. If a copy of the MPL was not distributed with this
%% file, You can obtain one at https://mozilla.org/MPL/2.0/.
%%
%% Copyright (c) 2007-2012 VMware, Inc.  All rights reserved.
%%

-module(lvc_SUITE).

-include_lib("eunit/include/eunit.hrl").
-include_lib("common_test/include/ct.hrl").
-include_lib("amqp_client/include/amqp_client.hrl").

-compile(export_all).

all() ->
    [
     {group, non_parallel_tests}
    ].

groups() ->
    [
     {non_parallel_tests, [], [
                               lvc,
                               lvc_bind_fanout_exchange,
                               lvc_bind_direct_exchange
                              ]}
    ].

%% -------------------------------------------------------------------
%% Testsuite setup/teardown.
%% -------------------------------------------------------------------

init_per_suite(Config) ->
    rabbit_ct_helpers:log_environment(),
    Config1 = rabbit_ct_helpers:set_config(Config, [
                                                    {rmq_nodename_suffix, ?MODULE}
                                                   ]),
    rabbit_ct_helpers:run_setup_steps(Config1,
                                      rabbit_ct_broker_helpers:setup_steps() ++
                                      rabbit_ct_client_helpers:setup_steps()).

end_per_suite(Config) ->
    rabbit_ct_helpers:run_teardown_steps(Config,
                                         rabbit_ct_client_helpers:teardown_steps() ++
                                         rabbit_ct_broker_helpers:teardown_steps()).

init_per_group(_, Config) -> Config.

end_per_group(_, Config) -> Config.

init_per_testcase(Testcase, Config) ->
    rabbit_ct_helpers:testcase_started(Config, Testcase).

end_per_testcase(Testcase, Config) ->
    rabbit_ct_helpers:testcase_finished(Config, Testcase).

%% -------------------------------------------------------------------
%% Testcases.
%% -------------------------------------------------------------------

lvc(Config) ->
    Ch = rabbit_ct_client_helpers:open_channel(Config),
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
    exchange_delete(Ch, X),
    rabbit_ct_client_helpers:close_channel(Ch).

lvc_bind_fanout_exchange(Config) ->
    Ch = rabbit_ct_client_helpers:open_channel(Config),
    LvcX = <<"test-lvc-exchange">>,
    X = <<"test-fanout-exchange">>,
    RK = <<"key1">>,
    Payload = <<"Hello world">>,
    exchange_declare(Ch, LvcX),
    exchange_declare(Ch, X, <<"fanout">>),
    Q1 = queue_declare(Ch),
    Q2 = queue_declare(Ch),
    bind(Ch, X, <<"">>, Q1),
    bind(Ch, X, <<"">>, Q2),
    publish(Ch, LvcX, RK, Payload),
    exchange_bind(Ch, X, RK, LvcX),
    expect(Ch, Q1, Payload),
    expect(Ch, Q2, Payload),
    exchange_delete(Ch, X),
    rabbit_ct_client_helpers:close_channel(Ch).

lvc_bind_direct_exchange(Config) ->
    Ch = rabbit_ct_client_helpers:open_channel(Config),
    LvcX = <<"test-lvc-exchange">>,
    X = <<"test-direct-exchange">>,
    RK = <<"key1">>,
    Payload = <<"Hello">>,
    exchange_declare(Ch, LvcX),
    exchange_declare(Ch, X, <<"direct">>),
    Q1 = queue_declare(Ch),
    Q2 = queue_declare(Ch),
    bind(Ch, X, RK, Q1),
    bind(Ch, X, RK, Q2),
    publish(Ch, LvcX, RK, Payload),
    exchange_bind(Ch, X, RK, LvcX),
    expect(Ch, Q1, Payload),
    expect(Ch, Q2, Payload),
    exchange_delete(Ch, X),
    rabbit_ct_client_helpers:close_channel(Ch).


%% -------------------------------------------------------------------
%% Helpers
%% -------------------------------------------------------------------

exchange_declare(Ch, X) ->
    amqp_channel:call(Ch, #'exchange.declare'{exchange    = X,
                                              type        = <<"x-lvc">>}).

exchange_declare(Ch, X, Type) ->
    amqp_channel:call(Ch, #'exchange.declare'{exchange    = X,
                                              type        = Type,
                                              auto_delete = true}).

exchange_delete(Ch, X) ->
    #'exchange.delete_ok'{} = amqp_channel:call(Ch, #'exchange.delete'{exchange = X}).

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
    after
        3000 ->
            ct:fail("Timeout waiting for message from queue ~s", [Q])
    end.

bind(Ch, X, RK, Q) ->
    amqp_channel:call(Ch, #'queue.bind'{queue       = Q,
                                        exchange    = X,
                                        routing_key = RK}).

exchange_bind(Ch, D, RK, S) ->
    amqp_channel:call(Ch, #'exchange.bind'{source       = S,
                                           destination  = D,
                                           routing_key  = RK}).
