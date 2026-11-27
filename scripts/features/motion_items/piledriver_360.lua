-- 360 owns its identity, input profile, approved combat values and source timing.
-- The motion input, combat and presentation instances execute this specification.
return {
    field='Piledriver360', key='circle_360', profile='circle_360',
    combat={
        normal={damage=3,splash=3,splashRadius=80,duration=54,sourceFrames=108,reach=16,grab=6,slam=42,release=44},
        od={damage=6,splash=3,splashRadius=80,duration=48,sourceFrames=108,reach=24,grab=6,slam=34,release=36},
    },
    frames={
        normal={{0,5,0,17},{6,39,18,65},{40,42,66,73},{43,43,78,78},{44,53,79,107}},
        od={{0,5,0,17},{6,29,18,65},{30,34,66,73},{35,35,78,78},{36,47,79,107}},
    },
}
