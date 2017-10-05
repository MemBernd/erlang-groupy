-module(gms2).
-compile(export_all).
-define(timeout, 2000).
-define(arghh, 100).

leader(Id, Master, Slaves, Group) ->
    %io:format("I, ~w am leader~n", [Id]),
    receive
        {mcast, Msg} ->
            bcast(Id, {msg, Msg}, Slaves),
            Master ! Msg,
            leader(Id, Master, Slaves, Group);
        {join, Wrk, Peer} ->
            Slaves2 = lists:append(Slaves, [Peer]),
            Group2 = lists:append(Group, [Wrk]),
            bcast(Id, {view, [self()|Slaves2], Group2}, Slaves2),
            Master ! {view, Group2},
            leader(Id, Master, Slaves2, Group2);
        stop ->
            ok
    end.

slave(Id, Master, Leader, Slaves, Group) ->
    %io:format("I, ~w am slave~n", [Id]),
    receive
        {mcast, Msg} ->
            Leader ! {mcast, Msg},
            slave(Id, Master, Leader, Slaves, Group);
        {join, Wrk, Peer} ->
            Leader ! {join, Wrk, Peer},
            slave(Id, Master, Leader, Slaves, Group);
        {msg, Msg} ->
            Master ! Msg,
            slave(Id, Master, Leader, Slaves, Group);
        {view, [Leader|Slaves2], Group2} ->
            io:format("group2: ~w, Master: ~w~n", [Group2, Master]),
            Master ! {view, Group2},
            slave(Id, Master, Leader, Slaves2, Group);
        {'DOWN', _Ref, process, Leader, _Reason} ->
            election(Id, Master, Slaves, Group);
        stop ->
            ok
    end.

election(Id, Master, Slaves, [_|Group]) ->
    Self = self(),
    case Slaves of
        [Self|Rest] ->
            bcast(Id, {view, Slaves, Group}, Rest),
            Master ! {view, Group},
            leader(Id, Master, Rest, Group);
        [Leader|Rest] ->
            erlang:monitor(process, Leader),
            slave(Id, Master, Leader, Rest, Group)
    end.

start(Id) ->
    Self = self(),
    {ok, spawn_link(fun() -> init(Id, Self) end)}.

init(Id, Master) ->
    Rnd = random:uniform(1000),
    random:seed(Rnd, Rnd, Rnd),
    leader(Id, Master, [], [Master]).

start(Id, Grp) ->
    Self = self(),
    {ok, spawn_link(fun() -> init(Id, Grp, Self) end)}.

init(Id, Grp, Master) ->
    Rnd = random:uniform(1000),
    random:seed(Rnd, Rnd, Rnd),
    Self = self(),
    Grp ! {join, Master, Self},
    receive
        {view, [Leader|Slaves], Group} ->
            erlang:monitor(process, Leader),
            Master ! {view, Group},
            slave(Id, Master, Leader, Slaves, Group)
        after ?timeout ->
            Master ! {error, "no reply from leader"}
    end.

bcast(Id, Msg, Slaves) ->
    lists:foreach(fun(Slave) -> Slave ! Msg, crash(Id) end, Slaves).
crash(Id) ->
    case random:uniform(?arghh) of
        ?arghh ->
            io:format("leader ~w: crash~n", [Id]),
            exit(no_luck);
        _ ->
            ok
        end.
