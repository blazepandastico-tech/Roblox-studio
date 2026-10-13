import sys, time
from core import *
from eggs import *
from animals import *
from render import *
def pre(m):
    return m
def shot(m, path, W=480):
    ss=2
    parts=[(p,(0,0,0)) for p in m.parts]
    eye,tg=fit_camera(parts)
    arr=render(parts,W*ss,W*ss,eye,tg)
    to_image(arr,ss).save(path)
t=time.time()
shot(build_egg(EGGS[2]),'/tmp/claude-0/e.png')
shot(mk_cow(),'/tmp/claude-0/a.png')
print(time.time()-t)
