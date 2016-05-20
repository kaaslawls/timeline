-- This example is built on LuaJit+FFI, the lua-void module and the SDL2 ffi binding:
-- luarocks install https://raw.github.com/torch/sdl2-ffi/master/rocks/sdl2-scm-1.rockspec
-- luarocks install https://raw.github.com/wizgrav/lua-void/master/rocks/void-1.rockspec

local sdl = require 'sdl2'
local ffi = require 'ffi'
local vision = require 'vision'
local void = require 'void'
local C = ffi.C

print(vision._VERSION)

sdl.init(sdl.INIT_VIDEO)

-- Init SDL
local window = sdl.createWindow("Lua vision example",
                                sdl.WINDOWPOS_CENTERED,
                                sdl.WINDOWPOS_CENTERED,
                                320,
                                240,
                                sdl.WINDOW_SHOWN)
local windowsurface = sdl.getWindowSurface(window)


-- We allocate two 1KB buffers to use with the runner
local b1,b2,b3,b4 = void(1024),void(1024),void(2400),void(1024)

-- Measurements by the runner all come in uint16s 
-- so let's set the view access types accordingly
b1.type,b2.type,b3.type,b4.type="u16","u16","u16","u16"

-- We create a runner declaring the metrics we require
-- in the exact order they will be placed in the buffers
local runner = vision.new("left-x","top-y","right-x","bottom-y","center-z","label")

-- LuaJIT FFI. The new C
local px = ffi.cast('uint8_t*',windowsurface.pixels)
local rect = ffi.new('SDL_Rect')
local event = ffi.new('SDL_Event')

local running = true
while running do
	
	while sdl.pollEvent(event) ~= 0 do
		if event.type == sdl.QUIT then
			running = false
		end
	end
	
	-- We need to tap the next frame before anything. This is a blocking call
	vision.tap()
	
	-- We setup the runner for the first pass. Far-near is the depth 
	-- range in mm and min is the minimum pixel count for inclusion 
	local depth = 2048
	local div = 256/depth
	runner.far = depth
	runner.near = 800
	runner.min = 2000
	runner.sub = 1
	b3[0]=0
	
	-- Calling the runner will perform a thorough frame scan and place data
	-- in the buffer. c1 holds the total number of uint16s written in b1
	local c1 = runner(b1,1,320,1,200)
	-- Ok let's start drawing. First, clear the window surface with SDL
	sdl.fillRect(windowsurface,nil,0)
	
	-- We'll focus on smaller blobs now so let's relax the pixel threshold
	runner.min = 200
	runner.sub=0
	
	-- Let's iterate the blobs we found on the first pass
	for i=1,c1,6 do
		-- Getting the measurements in packs of 5, just as we declared them
		local x,y,X,Y,z,l = b1(i,6)
		-- For every blob we'll run again with the second buffer 
		-- We'll scan 200mm closer than the average depth of each object
		-- we found on the first pass but this time we bound the scan area
		-- using the coordinates we obtained from the full frame scanning  
		-- This way we'll identify protrusions(hopefully limbs that extend) 
	
		rect.x,rect.y,rect.w,rect.h = x,y,X-x,Y-y
		sdl.fillRect(windowsurface,rect,255)

		local c4 = runner(b4,x,X,y,y+(Y-y)/5);
		local x,y,X,Y,z,l = b4(i,6)
		
		if c4 > 1 then
		rect.x,rect.y,rect.w,rect.h = x,y,X-x,Y-y
		sdl.fillRect(windowsurface,rect,100)

		rect.x,rect.y,rect.w,rect.h = (x+X)/2-4,(y+Y)/2-4,8,8
		sdl.fillRect(windowsurface,rect,255)
		end

	end
	
	sdl.updateWindowSurface(window)
	
end

sdl.destroyWindow(window)
sdl.quit()
