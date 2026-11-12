"""Mechanic-led puzzle layouts; no automatic insertion of solution drawings."""
from copy import deepcopy

def land(x1,x2,y,thickness=None,role='ground'):
    return dict(points=[[x1,y],[x2,y],[x2,900 if thickness is None else y+thickness],[x1,900 if thickness is None else y+thickness]],surface='solid',role=role)

def ferry(a,b,size=(180,22),period=5):
    return {'from':list(a),'to':list(b),'size':list(size),'period':period,'island':True}

def crate(x,y,ident='parcel',**kw):
    kw.setdefault('friction',0.5 if kw.get('release_on_ink_below') else 0.12)
    return dict(id=ident,position=[x,y],size=[36,36],mass=2,**kw)

def gate(px,gx,y,ident='parcel'):
    return dict(plate=[px,y],gate=[gx,y],crate_only=True,object_id=ident)

def roof(x1,x2,bottom):
    return dict(points=[[x1,0],[x2,0],[x2,bottom],[x1,bottom]],role='ceiling',surface='solid')

def stage(i,name,terrain,finish,hint,solution,**kw):
    d=dict(id=i,name=name,biome=0,width=finish[0]+180,height=900,start=[140,terrain[0]['points'][0][1]-20],finish=finish,
           terrain=terrain,hazards=[],platforms=[],crates=[],gates=[],winds=[],pickups=[],checkpoints=[],easy_checkpoints=[],
           build_regions=[],no_build_regions=[],allowed_inks=['solid','bounce','boost','ice','fragile'],ink=100,regen=5,budget=60,
           hint=hint,solution=solution,solution_strokes=[],solution_route=[],solution_ink_cost=0,puzzle_revision=3)
    d.update(kw)
    return d

def revise(levels):
    first=[]
    first.append(stage(1,'Spring to Sky Garden',[land(0,620,620),land(680,1320,470,32)], [1160,432],
      'The garden is too high for a normal jump. Draw a Bounce pad in the marked low strip.',
      'Draw a horizontal Bounce pad from (500,612) to (610,612). Approach right with speed, spring upward, and land on the garden.',
      build_regions=[[330,587,285,32]],allowed_inks=['bounce','solid'],solution_strokes=[dict(ink='bounce',points=[[500,612],[610,612]],reverse=False)]))
    first.append(stage(2,'Amber Headwind',[land(0,1900,620)],[1720,582],
      'The headwind defeats ordinary rolling. Boost along the gold work strip; stay grounded.',
      'Draw forward Boost from (350,612) to (1450,612). Its contact force overcomes the wind. Solid and Ice do not add propulsion.',
      winds=[dict(rect=[400,0,1100,900],force=[-2600,0])],build_regions=[[320,587,1180,32]],allowed_inks=['boost','solid','ice'],
      solution_strokes=[dict(ink='boost',points=[[350,612],[1450,612]],reverse=False)]))
    first.append(stage(3,'The Wandering Orchard',[land(0,400,580),land(660,790,490,26),land(1030,1600,500,35)],[1440,462],
      'Ride the moving island, jump onto the small orchard, then time the last landing. The channel is a no-build zone.',
      'Wait at the bank for the island, board it, jump up to the fixed orchard before passing beneath it, then jump to the final bank.',
      platforms=[ferry((500,560),(910,530),period=6)],build_regions=[[50,540,300,38]],no_build_regions=[[401,0,628,900]],hazards=[dict(rect=[401,780,628,120],type='water')]))
    first.append(stage(4,'Special Delivery',[land(0,1700,600),roof(1150,1370,480)],[1530,562],
      'Only the wooden parcel operates the crate-marked switch. Push it into the gold cradle; ink weights do not count.',
      'Push the parcel to x=1030. Hop over it after it settles in the cradle. The roof prevents jumping over the closed door.',
      crates=[crate(340,580)],gates=[gate(1030,1260,600)],build_regions=[[40,555,1450,40]]))
    first.append(stage(5,'Borrowed Time',[land(0,480,580),land(840,1480,580),roof(400,920,515)],[1310,542],
      'A low roof prevents jumping. You have twelve units of Fragile ink: bridge the tunnel and cross before it cracks.',
      'Draw Fragile from (480,572) to (840,572), release, and roll across before the 3.2-second collapse.',
      build_regions=[[430,530,460,49]],allowed_inks=['fragile'],ink=12,regen=0,solution_strokes=[dict(ink='fragile',points=[[480,572],[840,572]],reverse=False)]))
    first.append(stage(6,'Slippery Freight',[land(0,1740,720),land(580,1200,600,25),land(430,560,350,25),roof(1240,1410,600)],[1570,682],
      'The dispenser releases cargo when a chute is beneath it. Ice lets it slide into its switch; grippy Solid stalls it.',
      'Draw Ice from (558,342) to (1100,590). The parcel is nudged off its shelf, then slides by gravity into the cradle. Walk through the unlocked door.',
      crates=[crate(590,280,release_on_ink_below=True)],gates=[dict(plate=[1100,600],gate=[1330,720],crate_only=True,object_id='parcel')],build_regions=[[550,300,560,298]],allowed_inks=['ice','solid'],
      solution_strokes=[dict(ink='ice',points=[[558,342],[1100,590]],reverse=False)]))
    first.append(stage(7,'Two Keys, One Door',[land(0,1860,720),land(550,650,350,25),land(850,950,350,25),land(700,900,600,25),land(1000,1200,600,25),roof(1270,1610,600)],[1680,682],
      'Route each labelled parcel into its matching cradle. Both doors must be open; the wrong parcel does not count.',
      'Draw chutes from (648,330) to (800,590) and (948,330) to (1100,590). Route N and F into their matching elevated cradles, then walk below them through both doors.',
      crates=[crate(670,280,'near',release_on_ink_below=True),crate(970,280,'far',release_on_ink_below=True)],
      gates=[dict(plate=[800,600],gate=[1350,720],crate_only=True,object_id='near'),dict(plate=[1100,600],gate=[1510,720],crate_only=True,object_id='far')],
      build_regions=[[640,300,170,298],[940,300,170,298]]))
    first.append(stage(8,'Elevator Picnic',[land(0,400,620),land(680,800,460,28),land(900,1500,330,32)],[1340,292],
      'Board the floating elevator near its low point. Ride upward before jumping to the picnic ledge.',
      'Jump onto the elevator at x=550, wait for its high point at y=330, then jump right to the high garden. Direct bridging is forbidden over the shaft.',
      platforms=[ferry((550,600),(550,330),size=(170,24),period=7)],build_regions=[[40,575,300,40]],no_build_regions=[[401,0,498,900]]))
    first.append(stage(9,'Bounce and Brake',[land(0,620,600),land(750,940,420,30),land(1390,1850,440,35)],[1680,402],
      'Bounce up, brake onto the small garden, then catch the travelling island. Speed alone overshoots the landing.',
      'Use a Bounce pad at the first bank. Release direction or brake on the high garden. Board the ferry when aligned and jump to the exit.',
      platforms=[ferry((1040,470),(1300,440),size=(170,24),period=5)],build_regions=[[350,567,265,32]],allowed_inks=['bounce','solid']))
    first.append(stage(10,'Garden Contraption',[land(0,700,620),roof(520,610,490),land(1370,2030,420,35)],[1850,382],
      'Deliver the parcel first. Then time a spring onto the moving island and ride it toward the high exit.',
      'Push the parcel into its cradle to clear the bank door. Place Bounce on the bank beyond it, spring to the ferry, and time the last jump.',
      crates=[crate(320,600)],gates=[gate(460,565,620)],platforms=[ferry((900,580),(1190,480),size=(200,24),period=6)],
      build_regions=[[35,585,450,32],[620,585,75,32]],allowed_inks=['solid','bounce','boost']))
    levels[:10]=first
    # Preserve the 40 later authored multi-stage routes, but give every map a
    # mechanic-dependent final station rather than another interchangeable gap.
    for d in levels[10:]:
        w=d['width']; y=d['finish'][1]+38; mode=(d['id']-11)%5
        d['puzzle_revision']=3
        d['crates']=[]
        d['gates']=[]
        d['build_regions']=[[30,100,w-650,690]]
        if mode==0:
            d['terrain'].append(land(w+60,w+950,y-150,32)); d['width']=w+950; d['finish']=[w+780,y-188]
            d['build_regions'].append([w-360,y-33,355,32])
            d['hint']='Final station: spring from the low build strip to the high floating garden. A normal jump falls short.'
            d['solution']+=' Finish with a supported Bounce pad near the last bank and a controlled landing on the elevated island.'
        elif mode==1:
            d['terrain'].append(land(w,w+1400,y)); d['width']=w+1400; d['finish']=[w+1230,y-38]
            d['winds'].append(dict(rect=[w+170,0,1000,900],force=[-2600,0]))
            d['build_regions'].append([w-50,y-33,1250,32])
            d['hint']='Final station: a long headwind tunnel. Use forward Boost on the ground; jumping loses traction.'
            d['solution']+=' Draw forward Boost through the final headwind tunnel.'
        elif mode==2:
            d['terrain'] += [land(w,w+1300,y),roof(w+820,w+1050,y-120)]
            d['width']=w+1300; d['finish']=[w+1130,y-38]
            d['crates']=[crate(w+160,y-20,'station')]
            d['gates'].append(gate(w+650,w+930,y,'station'))
            d['build_regions'].append([w-80,y-45,900,40])
            d['hint']='Final station: push the wooden parcel into its own switch. Random ink weights cannot unlock this door.'
            d['solution']+=' Push the final parcel into the crate-marked cradle and pass beneath the roof.'
        else:
            rise=70 if mode==3 else 150
            d['terrain'].append(land(w+980,w+1660,y-rise,35)); d['width']=w+1660; d['finish']=[w+1490,y-rise-38]
            d['platforms'].append(ferry((w+190,y+15),(w+770,y-rise+20),size=(200,24),period=5.5+(d['id']%3)))
            d['no_build_regions']=[[w+1,0,978,900]]
            d['build_regions'].append([w-350,y-40,345,38])
            d['hint']='Final station: the channel cannot be built over. Time boarding the drifting island and jump when it reaches the far garden.'
            d['solution']+=' Board the moving island, ride toward the exit, then time the jump onto the raised garden.'
        d['name'] += [' · Spring Garden',' · Wind Machine',' · Parcel Lock',' · Island Hop',' · Sky Ferry'][mode]
