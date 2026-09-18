----------------------------------------
-- Bad Apple Turtle Display Feature
----------------------------------------
require("modules.utils.types")
require("modules.utils.states")
require("modules.systems.shaders")

local bit = bit or require("bit")

BadAppleManager = {}
BadAppleManager.__index = BadAppleManager

-- Constantes do Display
local WIDTH = 48
local HEIGHT = 36
local TOTAL_TURTLES = WIDTH * HEIGHT -- 1728
local SPACING = 32
local TOTAL_WIDTH = WIDTH * SPACING -- 1536
local TOTAL_HEIGHT = HEIGHT * SPACING -- 1152
local TOTAL_FRAMES = 900
local FRAME_DURATION = 1 / 30 -- 30 FPS
local BYTES_PER_FRAME = (WIDTH * HEIGHT) / 8 -- 216 bytes

-- Estado
BadAppleManager.isActive = false
BadAppleManager.currentFrame = 1
BadAppleManager.timer = 0
BadAppleManager.turtleAnimTimer = 0
BadAppleManager.turtleAnimFrame = 1

-- Recursos
local badAppleData = nil
local badAppleAudio = nil
local turtleImg = nil
local turtleQuads = {}
local turtleBatch = nil

-- Backup da Câmera
local savedCameraTarget = nil
local savedCameraTargetZoom = nil
local savedCameraZoomSpeed = nil

function BadAppleManager.init()
	-- Carregando os 900 frames binários (194.400 bytes)
	local binPath = "assets/data/badapple_900.bin"
	if love.filesystem.getInfo(binPath) then
		badAppleData = love.filesystem.read(binPath)
		print(string.format("[BadApple] Dados carregados com sucesso (%d bytes)", #badAppleData))
	else
		print("[BadApple] AVISO: Arquivo badapple_900.bin não encontrado!")
	end

	-- Carregando o áudio
	local audioPath = "assets/audios/global/badapple.mp3"
	if love.filesystem.getInfo(audioPath) then
		badAppleAudio = love.audio.newSource(audioPath, "stream")
		badAppleAudio:setLooping(false)
		print("[BadApple] Áudio carregado com sucesso")
	else
		print("[BadApple] AVISO: Arquivo de áudio badapple.mp3 não encontrado!")
	end

	-- Carregando sprite da tartaruga
	local turtlePath = pngPathFormat({ "assets", "animations", "interactives", "turtle", IDLE })
	turtleImg = assetManager:getImage(turtlePath)

	-- Quads de animação da tartaruga idle (2 frames de 32x32 com gap de 4px)
	turtleQuads[1] = love.graphics.newQuad(0, 0, 32, 32, turtleImg:getWidth(), turtleImg:getHeight())
	turtleQuads[2] = love.graphics.newQuad(36, 0, 32, 32, turtleImg:getWidth(), turtleImg:getHeight())

	-- Criando SpriteBatch dinâmico para 1728 tartarugas
	turtleBatch = love.graphics.newSpriteBatch(turtleImg, TOTAL_TURTLES, "dynamic")
end

function BadAppleManager.toggle()
	if BadAppleManager.isActive then
		BadAppleManager.stop()
	else
		BadAppleManager.start()
	end
end

function BadAppleManager.start()
	if not badAppleData or #badAppleData < TOTAL_FRAMES * BYTES_PER_FRAME then
		print("[BadApple] Erro: Dados de frames indisponíveis")
		return
	end

	BadAppleManager.isActive = true
	BadAppleManager.currentFrame = 1
	BadAppleManager.timer = 0
	BadAppleManager.turtleAnimTimer = 0
	BadAppleManager.turtleAnimFrame = 1

	-- Ajustando a câmera
	if cameras[1] and players[1] then
		local cam = cameras[1]
		local room = players[1].room or (rooms[0] and rooms[0][0])
		savedCameraTarget = cam.target
		savedCameraTargetZoom = cam.targetZoom
		savedCameraZoomSpeed = cam.zoomSpeed

		cam.target = nil
		if room then
			cam.targetPos = { x = room.pos.x, y = room.pos.y }
		end

		-- Zoom out suave para enquadrar perfeitamente a tela de 48x36 tartarugas
		local zoomX = cam.viewport.width / (TOTAL_WIDTH + 300)
		local zoomY = cam.viewport.height / (TOTAL_HEIGHT + 250)
		cam.targetZoom = math.min(zoomX, zoomY, 0.45)
		cam.zoomSpeed = 2.0
	end

	-- Pausando a música ambiente e tocando a música do Bad Apple
	if globalAudioManager then
		if globalAudioManager.musicPlaying and globalAudioManager.audios[globalAudioManager.musicPlaying] then
			globalAudioManager.audios[globalAudioManager.musicPlaying]:pause()
		end
	end

	if badAppleAudio then
		badAppleAudio:seek(0)
		badAppleAudio:play()
	end

	-- Constrói o primeiro frame no SpriteBatch
	BadAppleManager.rebuildBatch(1, 1)
	print("[BadApple] Iniciado com sucesso! (900 frames, 30 FPS)")
end

function BadAppleManager.stop()
	if not BadAppleManager.isActive then
		return
	end

	BadAppleManager.isActive = false

	-- Parando o áudio do Bad Apple
	if badAppleAudio then
		badAppleAudio:stop()
	end

	-- Retomando a música ambiente
	if globalAudioManager and globalAudioManager.musicPlaying then
		if globalAudioManager.audios[globalAudioManager.musicPlaying] then
			globalAudioManager.audios[globalAudioManager.musicPlaying]:play()
		end
	end

	-- Restaurando a câmera
	if cameras[1] then
		local cam = cameras[1]
		cam.target = savedCameraTarget or players[1]
		cam.targetZoom = savedCameraTargetZoom or cam:calculateZoom()
		cam.zoomSpeed = savedCameraZoomSpeed or 3.0
	end

	print("[BadApple] Parado.")
end

function BadAppleManager.rebuildBatch(frameNum, animFrame)
	if not turtleBatch or not badAppleData then
		return
	end

	turtleBatch:clear()
	local frameOffset = (frameNum - 1) * BYTES_PER_FRAME
	local quad = turtleQuads[animFrame] or turtleQuads[1]

	local byteIdx = 1
	local curByte = string.byte(badAppleData, frameOffset + byteIdx)
	local bitIdx = 7

	for r = 1, HEIGHT do
		local py = (r - 1) * SPACING
		for c = 1, WIDTH do
			local px = (c - 1) * SPACING
			local bitVal = bit.band(bit.rshift(curByte, bitIdx), 1)

			if bitVal == 1 then
				-- Pixel Branco: Tartaruga branca brilhante
				turtleBatch:setColor(1.0, 1.0, 1.0, 1.0)
			else
				-- Pixel Preto: Silhueta escura de tartaruga
				turtleBatch:setColor(0.04, 0.04, 0.07, 1.0)
			end

			turtleBatch:add(quad, px, py, 0, 1, 1, 16, 16)

			bitIdx = bitIdx - 1
			if bitIdx < 0 then
				bitIdx = 7
				byteIdx = byteIdx + 1
				if byteIdx <= BYTES_PER_FRAME then
					curByte = string.byte(badAppleData, frameOffset + byteIdx)
				end
			end
		end
	end
end

function BadAppleManager.update(dt)
	if not BadAppleManager.isActive then
		return
	end

	-- Atualiza animação de idle das tartarugas
	BadAppleManager.turtleAnimTimer = BadAppleManager.turtleAnimTimer + dt
	local animChanged = false
	if BadAppleManager.turtleAnimTimer >= 0.20 then
		BadAppleManager.turtleAnimTimer = 0
		BadAppleManager.turtleAnimFrame = (BadAppleManager.turtleAnimFrame % 2) + 1
		animChanged = true
	end

	-- Atualiza avanço dos frames do Bad Apple (30 FPS)
	BadAppleManager.timer = BadAppleManager.timer + dt
	local frameChanged = false
	while BadAppleManager.timer >= FRAME_DURATION do
		BadAppleManager.timer = BadAppleManager.timer - FRAME_DURATION
		BadAppleManager.currentFrame = BadAppleManager.currentFrame + 1
		frameChanged = true

		if BadAppleManager.currentFrame > TOTAL_FRAMES then
			-- Atingiu os 30 segundos (900 frames)
			BadAppleManager.stop()
			return
		end
	end

	if frameChanged or animChanged then
		BadAppleManager.rebuildBatch(BadAppleManager.currentFrame, BadAppleManager.turtleAnimFrame)
	end
end

function BadAppleManager.draw(camera)
	if not BadAppleManager.isActive or not turtleBatch then
		return
	end

	local room = (players[1] and players[1].room) or (rooms[0] and rooms[0][0])
	local cx = room and room.pos.x or 0
	local cy = room and room.pos.y or 0

	-- Top-left do grid no espaço de mundo (centralizado na sala)
	local startX = cx - TOTAL_WIDTH / 2 + SPACING / 2
	local startY = cy - TOTAL_HEIGHT / 2 + SPACING / 2

	local viewX, viewY = camera:viewPos(vec(startX, startY))

	-- Backdrop escuro para contraste perfeito da animação
	love.graphics.setColor(0.01, 0.01, 0.02, 1.0)
	love.graphics.rectangle("fill", viewX - 16, viewY - 16, TOTAL_WIDTH, TOTAL_HEIGHT)
	love.graphics.setColor(1, 1, 1, 1)

	-- Desenha usando whiteShader para que as cores no SpriteBatch definam o preenchimento exato
	love.graphics.setShader(whiteShader)
	whiteShader:send("fillColor", { 1.0, 1.0, 1.0, 1.0 })
	love.graphics.draw(turtleBatch, viewX, viewY)
	love.graphics.setShader()
end
