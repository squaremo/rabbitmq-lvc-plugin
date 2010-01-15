-module(rabbit_lvc_plugin).

-include("rabbit_lvc_plugin.hrl").

-define(APPNAME, ?MODULE).

-behaviour(application).
-behaviour(gen_server).

-export([start/2, stop/1]).
-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

%% Application

start(normal, []) ->
    io:format("starting ~s...", [?APPNAME]),
    ok = setup_schema(),
    {ok, SupPid} = rabbit_lvc_plugin_sup:start_link(),
    io:format(" done~n"),
    {ok, SupPid}.

stop(_State) ->
    ok.

%% For supervisor

start_link() ->
    gen_server:start_link({global, ?MODULE}, ?MODULE, [], []).

%% gen_server -- I don't need this (yet)

init([]) ->
  {ok, ok}.

handle_call(Msg,_From,State) ->
    {ok, State}.

handle_cast(_,State) -> 
    {noreply, State}.

handle_info(_Info, State) -> 
    {noreply, State}.

terminate(_,State) ->
    ok.

code_change(_OldVsn, State, _Extra) -> 
    {ok, State}.

%% private

setup_schema() ->
    case mnesia:create_table(?LVC_TABLE,
                             [{attributes, record_info(fields, cached)},
                              {record_name, cached},
                              {type, set}]) of
        {atomic, ok} -> ok;
        {aborted, {already_exists, ?LVC_TABLE}} -> ok
    end.
