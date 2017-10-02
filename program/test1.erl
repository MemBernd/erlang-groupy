-module(test1).
-compile(export_all)

start(MasterID) ->
    spawn_link(func() -> gms1:start(MasterID) end),
