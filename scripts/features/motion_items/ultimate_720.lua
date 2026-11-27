-- 720 has one variant, with native V9 control release at tick 289.
return {
    field='Ultimate720', key='circle_720', profile='circle_720',
    combat={normal={damage=15,splash=10,duration=394,sourceFrames=394,grab=0,slam=261,release=289}},
    -- Identity mapping: the combat tick is already the authored source frame.
    directFrames=true,
}
