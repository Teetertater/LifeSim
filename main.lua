--[[
Evolution Simulation by Yury Zhuk, Summer 2019

Start menu is controlled by arrow keys and return/enter.
Try various start parameters to see their effects.

Maximum Lifespan:             The Lifeforms will not live beyond this age even if they have enough energy
Target population:            This is an approximate control of the average population. The energy value of the food is
                                affected by the value set here (higher target --> food gives more energy)
Energy Consumption/Step:      A Lifeform making one step will consume this amount of energy
Energy Required for Birth:    The minimum energy required for both parents to produce an offspring
Energy at Birth:              The amount of energy each Lifeform starts with
Energy Used for Mating:       The amount used by both parents to create an offspring
Min Age of Reproduction:      Mating cannot occur before both parents have taken this many steps
Reproduction Cooldown(Steps): The number of steps a Lifeform must take between producing subsequent offspring
Mutation Rate:                Number of mutations that the Lifeform will undergo in its lifetime

In-game controls:
  Pause/Resume: Left/Right
  Speed up/Slowdown: Up/Down
  Mouseover displays information about a Lifeform.
  
Lifeforms consume energy with every step.
Dark horizontal lines represent food. Lifeforms walking over the lines will gain energy.
Mutations occur occasionally, a mutant Lifeform will take on a new colour.

]]--

love.window.setTitle("Life Simulation V1")

-- Constants
maxLifeSpan = 5000
maturityAge = 5
mutationRate = 5
targetPopulation = 60

consumptionRate = 0.45
birthEnergy = 0

startEnergy = 100
reprEnergy = 130
reproductionCooldown = 10

textHeight = 13

-- Variables
ticks = 0
energyFromFood = 20
mouse = {}

-- WINDOW DRAWING: Divide screen into cells. Each Lifeform/food takes up one cell
splashScreen = true
screenSize = 400
cellWidth = screenSize/80
pixels = math.floor(screenSize/cellWidth)
love.window.setMode( screenSize, screenSize)
timeSinceFrame = 0
speed = 5 --controls simulation speed

--Buttons
buttons = {
  goBox = {width = screenSize/4, height = 25, x = screenSize/2 - screenSize/8, y = screenSize-screenSize/6},
  resetBox = {width = screenSize/4, height = 25, x = screenSize/2 - screenSize/8, y = screenSize/2},
  vars = {varNumber = 9},
}
for i=1, buttons.vars.varNumber do buttons.vars[i] = {} end
buttons.vars[1].text = "Maximum Lifespan";              buttons.vars[1].value = maxLifeSpan;          buttons.vars[1].incr = 250
buttons.vars[2].text = "Target Population";             buttons.vars[2].value = targetPopulation;     buttons.vars[2].incr = 5
buttons.vars[3].text = "Energy Consumption/Step";       buttons.vars[3].value = consumptionRate;      buttons.vars[3].incr = 0.05 buttons.vars[4].text = "Energy Required for Birth";     buttons.vars[4].value = birthEnergy;          buttons.vars[4].incr = 5
buttons.vars[5].text = "Energy at Birth";               buttons.vars[5].value = startEnergy;          buttons.vars[5].incr = 25
buttons.vars[6].text = "Energy Used for Mating";        buttons.vars[6].value = reprEnergy;           buttons.vars[6].incr = 15
buttons.vars[7].text = "Min Age of Reproduction";       buttons.vars[7].value = maturityAge;          buttons.vars[7].incr = 45
buttons.vars[8].text = "Reproduction Cooldown (steps)"; buttons.vars[8].value = reproductionCooldown; buttons.vars[8].incr = 10
buttons.vars[9].text = "Mutation Rate";                 buttons.vars[9].value = 5;                    buttons.vars[9].incr = 1

function setVars()
  maxLifeSpan          =  buttons.vars[1].value 
  targetPopulation     =  buttons.vars[2].value 
  consumptionRate      =  buttons.vars[3].value 
  birthEnergy          =  buttons.vars[4].value 
  startEnergy          =  buttons.vars[5].value 
  reprEnergy           =  buttons.vars[6].value 
  maturityAge          =  buttons.vars[7].value 
  reproductionCooldown =  buttons.vars[8].value 
  mutationRate         =  maxLifeSpan/buttons.vars[9].value
end


-- movement -1 = left, 1 = right, 3 = up, 5 = down, 3 = up
mvTranslate = {}; mvTranslate[5]="V";   mvTranslate[-1]="<";  mvTranslate[1]=">"
                  mvTranslate[3]="/\\"; mvTranslate[-5]="/\\" mvTranslate[-3]="V"
                  
life = {length = 0}
Lifeform = {}; Lifeform.__index = Lifeform
function Lifeform:create(energy, x, y, dirX, dirY, colour, i, generation, walkSeq, walkSeqLen)
    local this = {
        gen = generation or 0,  
        birthday = ticks,       --keeps track during which tick the Lifeform was created
        reprCooldown = reproductionCooldown,
        x = x,
        y = y,
        i = i or 0,  --this represents which point along the walk sequence the Lifeform will start from on birth
        dirX = dirX or 1, --  or -1 for reversed. Direction control
        dirY = dirY or 1, --  or -1 for reversed
        energy = energy or startEnergy,
        
        --walkSeq reprents the "walk" sequence of the lifeform. Each number encodes a relative direction that the Lifeform
        --will walk in. It will iterate through the sequence one-by-one in order on repeat. This is set at birth and can be mutated
        mTraits = {
          mutation_rate = mutationRate,
          walkSeq = walkSeq or {5,-1,3,-1,5,5,-1}, 
          walkSeqLen = walkSeqLen or 7,
          colour = colour or {0,255,0}, --lime
        }
    }
    setmetatable(this, Lifeform); return this
end

function Lifeform:walk() 
    --Increments the step of the Lifeform when called (moves the Lifeform by 1 step) depending
    --on the steps defined in the Lifeform's walk sequence and counter (i)
    
    self.i = self.i < self.mTraits.walkSeqLen and self.i + 1 or 1
    nextStep = self.mTraits.walkSeq[self.i]
    if nextStep < 2 then --nextStep -1 or 1 means left-right, so impacts x
      self.x = self.x + nextStep*self.dirX
      self.x = self.x <= 0 and pixels or self.x -- wrap bounds
      self.x = self.x > pixels and 1 or self.x
    else --nextStep 3 or 5 means up-down, so impacts y
      self.y = self.y + (nextStep - 4)*self.dirY 
      self.y = self.y <= 0 and pixels or self.y
      self.y = self.y > pixels and 1 or self.y
    end
    self.energy = self.energy - consumptionRate
end

function Lifeform:mutate() 
    --Controls the mutation of the Lifeform
    if ticks - self.birthday % mutationRate == mutationRate then --mutate every mutationAge ticks
      m = math.ceil(math.random()*10) % 2 --choose which mTrait (mutable trait) to modify
      if m == 0 then 
        --randomly pick a step along the walk sequence and modify it. 1/4 chance of not changing
        stepToMutate = (math.ceil(math.random()*10) % (self.mTraits.walkSeqLen-1)) + 1
        possibleSteps = {1, -1, 3, 5}
        self.mTraits.walkSeq[stepToMutate] = possibleSteps[(math.ceil(math.random()*10) % 3) + 1]
      elseif m == 1 then 
        --either make the walk sequence longer or shorter. If longer copy last, if shorter cut last step
        if math.ceil(math.random()*10) % 2 then
          self.mTraits.walkSeq[self.mTraits.walkSeqLen + 1] = self.mTraits.walkSeq[self.mTraits.walkSeqLen]
          self.mTraits.walkSeqLen = self.mTraits.walkSeqLen + 1
        else
          self.mTraits.walkSeq[self.mTraits.walkSeqLen] = nil
          self.mTraits.walkSeqLen = self.mTraits.walkSeqLen - 1
        end
      end
      --always mutate colour
      self.mTraits.colour = {math.random(),math.random(),math.random()}
    end
end

--deadIndex is an array containing the indices of the life array which are nil (when a Lifeform has died).
--This is used for births to create a Lifeform in place of a dead one instead of making the life array longer.
deadIndex = {length=0}
function deadIndex:death(i) --record which spot along the life index is becoming nil/free
    self.length = self.length + 1
    self[self.length] = i
    life[i] = nil
end
function deadIndex:birth() --remove the newborn from the deadIndex and place into life index
    newIndex = self[self.length]
    self[self.length] = nil
    self.length = self.length - 1
    return newIndex
end

function birth(m, d)
  --function controlling creation of new Lifeforms (upon collision of any two Lifeforms.)
  if m.energy > reprEnergy and d.energy > reprEnergy and
     m.reprCooldown <= 0 and d.reprCooldown <= 0     and 
     (ticks-m.birthday) > maturityAge and (ticks-d.birthday) > maturityAge then
    --Lifeform creation can only happen if both parents have enough energy and both reproduction cooldowns are elapsed
    m.energy = m.energy - birthEnergy
    d.energy = d.energy - birthEnergy
    --child colour will be an average of parents'
    colour = {(m.mTraits.colour[1] + d.mTraits.colour[1])/2,
              (m.mTraits.colour[2] + d.mTraits.colour[2])/2,
              (m.mTraits.colour[3] + d.mTraits.colour[3])/2}
    --create newborn with a combination of parents' traits
    newborn = Lifeform:create(startEnergy, m.x, d.y, -1*m.dirX, -1*d.dirY, colour,
                              1, math.max(m.gen, d.gen)+1, m.walkSeq, m.walkSeqLen)
    --if there is a free slot in the life array, fill it in with the newborn
    if deadIndex.length >= 1 then
      life[deadIndex:birth()] = newborn
    else
      life[life.length + 1] = newborn
      life.length = life.length + 1
    end
    newborn = Lifeform:create(startEnergy, d.x, m.y, d.dirX, m.dirY, colour, --repeat again (produces two children)
                              1, math.max(m.gen, d.gen)+1, d.walkSeq, d.walkSeqLen)
    if deadIndex.length >= 1 then
      life[deadIndex:birth()] = newborn
    else
      life[life.length + 1] = newborn
      life.length = life.length + 1
    end
    --restart reproduction cooldown for both parents
    m.reprCooldown = m.reprCooldown + reproductionCooldown
    d.reprCooldown = d.reprCooldown + reproductionCooldown
  end
end

--initialize Food. The food array contains positional information of the food. This is used to determine
--when Lifeforms occupy the same cell as food
food = {}; lifeDisplayed = {}
for i=1, pixels do
  food[i] = {}     -- create a new row
  for j=1,pixels do
    food[i][j] = 0
  end
end
foodLineWidth = pixels
function Lifeform:feed()
    if food[self.x][self.y] > 0 then
      self.energy = self.energy + energyFromFood
      food[self.x][self.y] = -5
    end
end

function resetLifeDisplayed()
  --lifeDisplayed contains indices of the Lifeforms visible on the screen at every point
  --Used for determining the Lifeform index on mouseover
  --this gets overwritten if a Lifeform goes "on top" of another, so cannot be used for mating
  lifeDisplayed = {}
  for i=1, pixels do
    lifeDisplayed[i] = {}
    for j=1,pixels do
      lifeDisplayed[i][j] = nil
    end
  end
end
resetLifeDisplayed()

function Lifeform:checkOthersPos(i)
  --function used for mating; to check if there is another lifeform
  --at the current position and call the birthing function
  for j=1, life.length do
    life2 = life[j]
    if (life2 ~= nil and i~=j and life2.x == self.x and life2.y == self.y) then
      birth(life2, self)
    end
  end
end

--Keyboard controls. Up = faster, Down = slower, Left = pause, Right = Resume
beforePausedSpeed = 0
function controlSpeed()
    if love.keyboard.isDown("up") then
      speed = speed + 0.5
    end
    if love.keyboard.isDown("down") then
      speed = speed - 0.5
      speed = speed < 0 and 0 or speed
    end
    if love.keyboard.isDown("left") and speed > 0 then
      beforePausedSpeed = speed
      speed = 0
    end
    if love.keyboard.isDown("right") and speed == 0 then
      speed = beforePausedSpeed
      beforePausedSpeed = 0
    end
end

function mouseOverInfo()
  --Information printed on screen when mouse mousese over a lifeform
    if love.mouse.isVisible() then
      mouse.x, mouse.y = love.mouse.getPosition()
      if mouse.x <= screenSize and mouse.y <= screenSize and mouse.x >=0 and mouse.y >=0 then
        x, y = math.floor(mouse.x/cellWidth) + 1, math.floor(mouse.y/cellWidth) + 1
        moLife = lifeDisplayed[x][y] --gets the life at the position of the mouse
        
        if moLife ~= nil then
          ws = "" -- this for loop turns the walk sequence into a string
          for i=1, moLife.mTraits.walkSeqLen do
            step = moLife.mTraits.walkSeq[i]
            step = step < 2 and mvTranslate[step*moLife.dirX] or mvTranslate[step*moLife.dirY]
            ws = moLife.i == i and ws.."("..step.."), " or ws..step..", "
          end
          top = 8 --how high the first line is printed on the left of the screen. Further lines will be below it
          love.graphics.setColor(unpack(moLife.mTraits.colour))
          love.graphics.print("LIFEFORM:", 0, screenSize-textHeight*top)
          love.graphics.setColor(1,1,1)
          love.graphics.print("Generation:   "..(moLife.gen), 0, screenSize-textHeight*(top-1))
          love.graphics.print("Age:              "..(ticks-moLife.birthday), 0, screenSize-textHeight*(top-2))
          love.graphics.print("Coordinates:  "..(moLife.x)..", "..(moLife.y), 0, screenSize-textHeight*(top-3))
          love.graphics.print("Energy:         "..(math.ceil(moLife.energy)), 0, screenSize-textHeight*(top-4))
          love.graphics.print("Walk Sequence:", 0, screenSize-textHeight*(top-5))
          love.graphics.print(ws, 0, screenSize-textHeight*(top-6))
        end
      end
    end
end

function initAll()
  setVars()
  
  for i=1, foodLineWidth do 
    --create two horizontal lines of food evenly spaces across the screen
    x,y1, y2 = screenSize/cellWidth - foodLineWidth + i, screenSize/4/cellWidth, screenSize/4/cellWidth*3
    food[math.floor(x)][math.floor(y1)] = energyFromFood
    food[math.floor(x)][math.floor(y2)] = energyFromFood
  end
  
  --initialize Lifeforms with arbitrary locations and walk sequences
  for i=1, 3 do
    --creates 9 lifeforms; 3 clusters of 3 with varying walk sequences, directions, and colours
    w1,w2,w3 = {5,-1,3,-1,5,5,-1}, {3,3,-1,-1,5,-1,-1}, {3,-1,-1,-1,-1,-1,3}
  
    x1, y1 = pixels /4 + (i), pixels/4 - (i%3%2)
    x2, y2 = pixels /2 + (i%2), (pixels-pixels/4)-(i%3%2)
    x3, y3 = pixels - pixels /4 + (i%2), pixels/4 + (i%3%2)
    dirx, diry = math.pow(-1, i), math.pow(-1, i%3%2)
    
    life[1+3*(i-1)] = Lifeform:create(startEnergy, x1, y1, dirx, diry, {0,1,0}, i%7, 0, w1)
    life[2+3*(i-1)] = Lifeform:create(startEnergy, x2, y2, dirx, diry, {1,0,0}, i%7, 0, w2)
    life[3+3*(i-1)] = Lifeform:create(startEnergy, x3, y3, dirx, diry, {1,0,1}, i%7, 0, w3)
    life.length = life.length + 3
  end
  alive = life.length
end

selectedBox = 1
downReleased = false; upReleased = false; leftReleased = false; rightReleased = false; enterReleased = false
function love.keyreleased(key)
  if key == "down" then
    downReleased = true
  elseif key == "up" then
    upReleased = true
  elseif key == "left" then
    leftReleased = true
  elseif key == "right" then
    rightReleased = true
  elseif key == "return" then
    enterReleased = true
  end
end
function controlSplash()
  x,y = love.mouse.getPosition()
  goBox = buttons.goBox
  if x > goBox.x and y > goBox.y and x < goBox.x + goBox.width and 
     y < goBox.y + goBox.height and love.mouse.isDown(1) or enterReleased then
    enterReleased = false
    splashScreen = false
    initAll()
  end
    if upReleased then
      upReleased = false
      selectedBox = selectedBox - 1
      selectedBox = selectedBox < 1 and 1 or selectedBox 
    end
    if downReleased then
      downReleased = false
      selectedBox = selectedBox + 1
      selectedBox = selectedBox > buttons.vars.varNumber and buttons.vars.varNumber or selectedBox 
    end
    if leftReleased then
      leftReleased = false
      buttons.vars[selectedBox].value = buttons.vars[selectedBox].value - buttons.vars[selectedBox].incr
    end
    if rightReleased then
      rightReleased = false
      buttons.vars[selectedBox].value = buttons.vars[selectedBox].value + buttons.vars[selectedBox].incr
    end
end    

function resetAll()
  resetLifeDisplayed()
  life = {length = 0}
  deadIndex.length = 0
  ticks = 0
  energyFromFood = 20
  speed = 5
  selectedBox = 1
  downReleased = false; upReleased = false; leftReleased = false; rightReleased = false
end

function controlReset()
  resetBox = buttons.resetBox
  x,y = love.mouse.getPosition()
  if x > resetBox.x and y > resetBox.y and x < resetBox.x + resetBox.width and
     y < resetBox.y + resetBox.height  and love.mouse.isDown(1) or enterReleased then
      enterReleased = false
      resetAll()
      initAll()
      splashScreen = true
  end
end
    
--Some stats printed at the top of the screen. Oldest = the oldest lifeform alive, alive = number of lifeforms alive
--dt_global is the global delta time
oldest = 999999999999 ;maxGen = 0; alive = 12; maxPop = 0; dt_global = 0
function love.update(dt)
    --[[ 
    The main function controling world updates. dt = delta time, the time since the last time this function was called. 
    In order to run the game at a specific rate, we accumulate the delta time in timeSinceFrame until the required time 
    passed to render the next frame. 
    
    ]]--
    --next frame. 
    if splashScreen then
      controlSplash()
    else
      controlSpeed()
      dt_global = dt
      timeSinceFrame = timeSinceFrame + dt
      if timeSinceFrame > 1/speed and alive > 0 then
        --iters controls the amount of frames to skip rendering.
        --once speed surpasses max fps (60), start skipping frames
        iters = speed>60 and speed-58 or 1
        for it=1, iters do
          ticks = ticks + 1 --global clock
          maxPop = math.max(maxPop, alive); oldest = 999999999999; alive = 0 
          for i=1, life.length do 
            --update every Lifeform 
            lifeform = life[i]
            if lifeform ~= nil then
              maxGen = math.max(maxGen, lifeform.gen) --update stats
              oldest = math.min(oldest, lifeform.birthday)
              alive = alive + 1
              
              --allow death of Lifeform if it reaches max age or runs out of energy
              if ticks - lifeform.birthday > maxLifeSpan or lifeform.energy <= 0 then
                deadIndex:death(i)
              else
                --decrement reproduction cooldown
                lifeform.reprCooldown = lifeform.reprCooldown > 0 and lifeform.reprCooldown - 1 or lifeform.reprCooldown
                lifeform:feed()             --if position matches position of food, increase energy
                lifeform:checkOthersPos(i)  --if position matches another life, call mating func
                lifeform:mutate()
                lifeform:walk()
              end
            end
          end
        end
        energyFromFood = targetPopulation*27/alive
        --this is a hackey population control. If life is too plentiful, decrease the nutritional value of food and vice-versa
        timeSinceFrame = 0
      elseif alive <= 0 then
        controlReset()
      end
    end
end

timeSinceRegen = 0
function drawOneFood(i,j)
  --controls drawing and respawning of food
  --a food index of below 0 is a ticker representing ticks until the food can respawn again
  --only draw the food if its value is above 0 (this is separate from its nutritional value)
  if food[i][j] > 0 then 
    x = (i-1)*cellWidth
    y = (j-1)*cellWidth
    love.graphics.rectangle("fill", x, y, cellWidth, cellWidth)
  elseif food[i][j] < 0 then
    if timeSinceRegen > 1/speed then
      food[i][j] = food[i][j] + 2 
      timeSinceRegen = 0
    else --food respawning should happen at the same speed as the movement of life
      iters = speed>60 and speed-58 or 1
      timeSinceRegen = timeSinceRegen + dt_global*iters/35
    end
  else
  end
end

function showSplashScreen()
  love.graphics.setColor(0, 0.2, 0.2) --turquoise
  love.graphics.rectangle("fill", 0, 0, screenSize, screenSize)
  
  goBox = buttons.goBox
  love.graphics.setColor(0, 0.1, 0.1)
  love.graphics.rectangle("fill", goBox.x, goBox.y, goBox.width, goBox.height)
  love.graphics.setColor(1,1,1);
  love.graphics.print("GO", goBox.x+40, goBox.y+5)
  
  top = 13; spacing = 30
  for i=1, buttons.vars.varNumber do
    love.graphics.setColor(0, 0.15, 0.15)
    love.graphics.rectangle("fill", screenSize/2-goBox.width-40, screenSize-(top-i)*spacing, goBox.width*2, goBox.height)
    love.graphics.rectangle("fill", screenSize/2+goBox.width-15, screenSize-(top-i)*spacing, goBox.width/2, goBox.height)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(buttons.vars[i].text, screenSize/2-goBox.width-35, screenSize-(top-i)*spacing+5)
    love.graphics.print(buttons.vars[i].value, screenSize/2+goBox.width-10, screenSize-(top-i)*spacing+5)
  end
  k = selectedBox
  love.graphics.setColor(0, 0.1, 0.1)
  love.graphics.polygon("fill", screenSize/2+goBox.width - 20, screenSize-(top-k)*spacing,
                                 screenSize/2+goBox.width - 20, screenSize-(top-k)*spacing+goBox.height, 
                                 screenSize/2+goBox.width - 30, screenSize-(top-k)*spacing+goBox.height/2)
  love.graphics.polygon("fill", screenSize/2+goBox.width + 40, screenSize-(top-k)*spacing,
                                 screenSize/2+goBox.width + 40, screenSize-(top-k)*spacing+goBox.height, 
                                 screenSize/2+goBox.width + 50, screenSize-(top-k)*spacing+goBox.height/2)
end

function love.draw()
  if splashScreen then
    showSplashScreen()
  end
  if alive > 0 and splashScreen == false then
    love.graphics.setColor(0, 0.2, 0.2) --turquoise
    love.graphics.rectangle("fill", 0, 0, screenSize, screenSize)
    love.graphics.setColor(0,0.1,0.1) --food colour
    
    for i=1, pixels do
      for j=1,pixels do
        drawOneFood(i,j)
      end
    end
    
    --display Lifeforms. Extrapolate their X,Y cell-grid coordinates into X,Y cartesian coordinates
    resetLifeDisplayed()
    for i=1, life.length do
      if life[i] ~= nil then
        lifeform = life[i]
        lifeDisplayed[lifeform.x][lifeform.y] = lifeform
        x, y = (lifeform.x-1)*cellWidth + cellWidth/2, (lifeform.y-1)*cellWidth + cellWidth/2
        love.graphics.setColor(unpack(lifeform.mTraits.colour))
        love.graphics.circle("fill", x, y, cellWidth/2)
      end
    end
    
    --draw stats in white
    love.graphics.setColor(1,1,1)
    love.graphics.print("Total life: "..(alive))
    love.graphics.print("Oldest life:  "..(math.max(ticks-oldest, 0)), 0, textHeight*1)
    love.graphics.print("Maximum generation:  "..maxGen, 0, textHeight*2)
    love.graphics.print("World age:  "..ticks, 0, textHeight*3)
    love.graphics.print("Speed:  "..speed, 0, textHeight*4)
    
    mouseOverInfo() --render mouseover stats
    
  elseif alive <= 0 then
    resetButtonActive = true
    love.graphics.setColor(0, 0.2, 0.2); h = 15
    love.graphics.rectangle("fill", 0, 0, screenSize, screenSize)
    love.graphics.setColor(1,1,1);
    love.graphics.print("Simulation Complete! No Lifeforms remaining", screenSize/6, screenSize/2-10*h)
    love.graphics.print("World age: "..(ticks), screenSize/6, screenSize/2-9*h)
    love.graphics.print("Oldest generation:  "..maxGen, screenSize/6, screenSize/2-8*h)
    love.graphics.print("Maximum population:  "..maxPop, screenSize/6, screenSize/2-7*h)
    
    resetBox = buttons.resetBox
    love.graphics.setColor(0, 0.1, 0.1)
    love.graphics.rectangle("fill", resetBox.x, resetBox.y, resetBox.width, resetBox.height)
    love.graphics.setColor(1,1,1);
    love.graphics.print("RESET", resetBox.x+30, resetBox.y+5)
  end
end
