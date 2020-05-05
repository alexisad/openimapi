template dbg*(x: untyped): untyped =
    when not defined(release):
        x