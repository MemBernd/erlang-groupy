-module(gms3).
-compile(export_all).
-define(timeout, 2000).
-define(arghh, 100).
-define(zero, 0).

leader(Id, Master, Slaves, Group, N) ->
    %io:format("I, ~w am leader~n", [Id]),
    receive
        {mcast, Msg} ->
            bcast(Id, {msg, Msg, N}, Slaves),
            Master ! Msg,
            leader(Id, Master, Slaves, Group, N+1);
        {join, Wrk, Peer} ->
            Slaves2 = lists:append(Slaves, [Peer]),
            Group2 = lists:append(Group, [Wrk]),
            bcast(Id, {view, [self()|Slaves2], Group2, N}, Slaves2),
            Master ! {view, Group2},
            leader(Id, Master, Slaves2, Group2, N+1);
        stop ->
            ok
    end.

slave(Id, Master, Leader, Slaves, Group, N, Last) ->
    %io:format("I, ~w am slave~n", [Id]),
    receive
        {mcast, Msg} ->
            Leader ! {mcast, Msg},
            slave(Id, Master, Leader, Slaves, Group, N, Last);
        {join, Wrk, Peer} ->
            Leader ! {join, Wrk, Peer},
            slave(Id, Master, Leader, Slaves, Group, N, Last);
        {msg, _, D} when D < N ->
            slave(Id, Master, Leader, Slaves, Group, N, Last);
        {msg, Msg, D} ->
            Master ! Msg,
            slave(Id, Master, Leader, Slaves, Group, D+1, {msg, Msg, D});
        {view, [Leader|Slaves2], Group2, D} ->
            Master ! {view, Group2},
            slave(Id, Master, Leader, Slaves2, Group, D+1, {view, [Leader|Slaves2], Group2, D});
        {'DOWN', _Ref, process, Leader, _Reason} ->
            election(Id, Master, Slaves, Group, N, Last);
        stop ->
            ok
    end.

election(Id, Master, Slaves, [_|Group], N, Last) ->
    Self = self(),
    case Slaves of
        [Self|Rest] ->
            bcast(Id, Last, Rest),
            bcast(Id, {view, Slaves, Group, N+1}, Rest ),
            Master ! {view, Group},
            leader(Id, Master, Rest, Group, N+2);
        [Leader|Rest] ->
            erlang:monitor(process, Leader),
            slave(Id, Master, Leader, Rest, Group, N, Last)
    end.

start(Id) ->
    Self = self(),
    {ok, spawn_link(fun() -> init(Id, Self) end)}.

init(Id, Master) ->
    Rnd = random:uniform(1000),
    random:seed(Rnd, Rnd, Rnd),
    leader(Id, Master, [], [Master], ?zero).

start(Id, Grp) ->
    Self = self(),
    {ok, spawn_link(fun() -> init(Id, Grp, Self) end)}.

init(Id, Grp, Master) ->
    Rnd = random:uniform(1000),
    random:seed(Rnd, Rnd, Rnd),
    Self = self(),
    Grp ! {join, Master, Self},
    receive
        {view, [Leader|Slaves], Group, N} ->
            erlang:monitor(process, Leader),
            Master ! {view, Group},
            slave(Id, Master, Leader, Slaves, Group, N, "nope")
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
