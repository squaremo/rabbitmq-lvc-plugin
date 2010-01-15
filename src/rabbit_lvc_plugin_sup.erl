-module(rabbit_lvc_plugin_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() ->
  supervisor:start_link({local, ?MODULE}, ?MODULE, _Arg = []).

init([]) ->
    {ok, {{one_for_one, 3, 10},
          [{rabbit_lvc_plugin,
            {rabbit_lvc_plugin, start_link, []},
            permanent,
            10000,
            worker,
            [rabbit_lvc_plugin]}
          ]}}.
