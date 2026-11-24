-- V9 screen framing only. No actors, animation state, damage or saved state.
local C={backdrop='gfx/Effects/MotionShowcase/cinematic_v1/scene.anm2'}
function C.Layout(frame,w,h,facing)
 local scale=math.min(w/320,h/208);local mirror=facing=='left'
 local center=Vector(w/2,h/2+20*scale)
 return {cinema=true,scale=scale,rotation=0,mirror=mirror,point=function(x,y)
  return center+Vector((mirror and -x or x)*scale,y*scale)
 end}
end
function C.Pose(frame,layout,tick)
 -- The approved V9 source uses theta=(t-217)*.68 for its airborne turn.
 -- Retain that whole-actor yaw when the actor is drawn in screen framing.
 local x=frame.body[3]
 if tick and tick>=217 and tick<255 then x=math.abs(x)*math.cos((tick-217)*.68)end
 return {scaleX=x/100*layout.scale*(layout.mirror and -1 or 1),
  scaleY=frame.body[4]/100*layout.scale,rotation=frame.body[5]*(layout.mirror and -1 or 1),cinema=true}
end
return C
