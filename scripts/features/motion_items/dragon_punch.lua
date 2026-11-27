-- Dragon Punch uses the existing horizontal-only DP recognizer adapter.
return {
    field='DragonPunch', key='dp', profile='dp', anyDirection=true,
    combat={
        normal={damage=2,duration=30,sourceFrames=78,length=48,radius=18,windows={{6,15}}},
        od={damage={2,3},duration=50,sourceFrames=78,length=56,radius=20,windows={{6,12},{22,32}}},
    },
    frames={
        normal={{0,5,0,17},{6,15,18,42},{16,29,43,77}},
        od={{0,5,0,17},{6,12,18,29},{13,21,30,37},{22,32,38,53},{33,49,54,77}},
    },
}
