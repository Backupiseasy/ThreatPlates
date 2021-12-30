---------------------------------------------------------------------------------------------------
-- Animations
---------------------------------------------------------------------------------------------------
local ADDON_NAME, Addon = ...

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs
local pairs, next, floor, abs = pairs, next, floor, abs

-- WoW APIs
local UIParent = UIParent

-- ThreatPlates APIs
local Animations = Addon.Animations

---------------------------------------------------------------------------------------------------
-- Local variables
---------------------------------------------------------------------------------------------------
-- ShowPlateDuration
local HidePlateDuration, FadeToDuration, ScaleToDuration, FlashDuration
local HidePlateFadeOut, HidePlateScaleDown

---------------------------------------------------------------------------------------------------
-- Cached configuration settings (for performance reasons)
---------------------------------------------------------------------------------------------------
local Settings

---------------------------------------------------------------------------------------------------
-- Animation Function (OnUpdate on a frame)
---------------------------------------------------------------------------------------------------

local function SetPlateScale(frame, scale)
  frame:SetScale(scale) -- poor man's scale ...

  --local style = frame.style.healthbar
  --local width, height = style.width, style.height
  --
  --frame:SetSize(floor(width * scale), floor(height * scale))
  --
  --local bar = frame.visual.Healthbar
  --bar:SetSize(floor(width * scale), floor(height * scale))

  --local bar = frame.visual.Castbar
  --width = floor(width * scale)
  --height = floor(height * scale)
  --bar:SetSize(floor(width * scale), floor(height * scale)
end

local AnimationFrame = CreateFrame("Frame", "ThreatPlatesAnimation", UIParent)
local AnimatedFrames = {}

local function AnimationOnUpdate(self, elapsed)
  for frame, _ in pairs(AnimatedFrames) do
    local animation_on_frame = false

    if frame:IsShown() then
      local animation = frame.FadeAnimation
      if animation and animation.Playing then
        animation.Timer = animation.Timer + elapsed

        if animation.Timer < animation.Duration then
          -- perform animation
          frame:SetAlpha((animation.Timer / animation.Duration) * (animation.TargetAlpha - animation.StartAlpha) + animation.StartAlpha)
          animation_on_frame = true
        else
          -- animation has ended
          frame:SetAlpha(animation.TargetAlpha)
          animation.Playing = nil
        end
      end

      animation = frame.ScaleAnimation
      if animation and animation.Playing then
        animation.Timer = animation.Timer + elapsed

        if animation.Timer < animation.Duration then
          -- perform animation
          --frame:SetScale((animation.Timer / animation.Duration) * (animation.TargetScale - animation.StartScale) + animation.StartScale)
          local scale = (animation.Timer / animation.Duration) * (animation.TargetScale - animation.StartScale) + animation.StartScale
          SetPlateScale(frame, scale)
          animation_on_frame = true                                   
        else
          -- animation has ended
          SetPlateScale(frame, animation.TargetScale)
          animation.Playing = nil
        end
      end
    end

    if not animation_on_frame then
      AnimatedFrames[frame] = nil
    end
  end

  if not next(AnimatedFrames) then
    AnimationFrame:Hide()
  end
end

AnimationFrame:SetFrameStrata("BACKGROUND")
AnimationFrame:SetAllPoints()
AnimationFrame:SetScript('OnUpdate', AnimationOnUpdate)
AnimationFrame:Hide()

---------------------------------------------------------------------------------------------------
-- Animation Functions
---------------------------------------------------------------------------------------------------

function Animations:CreateFlash(frame)
  frame.FlashAnimation = frame:CreateAnimationGroup("Flash")
  frame.FlashAnimation.FadeIn = frame.FlashAnimation:CreateAnimation("ALPHA", "FadeIn")
  frame.FlashAnimation.FadeIn:SetFromAlpha(0)
  frame.FlashAnimation.FadeIn:SetToAlpha(1)
  frame.FlashAnimation.FadeIn:SetOrder(2)

  frame.FlashAnimation.FadeOut = frame.FlashAnimation:CreateAnimation("ALPHA", "FadeOut")
  frame.FlashAnimation.FadeOut:SetFromAlpha(1)
  frame.FlashAnimation.FadeOut:SetToAlpha(0)
  frame.FlashAnimation.FadeOut:SetOrder(1)
end

function Animations:CreateFlashLoop(frame)
  self:CreateFlash(frame)

  frame.FlashAnimation:SetScript("OnFinished", function(_, requested)
    if not requested then
      frame.FlashAnimation:Play()
    end
  end)
end

function Animations:Flash(frame)
  if not frame.FlashAnimation then
    self:CreateFlashLoop(frame)
  end

  local animation = frame.FlashAnimation
  if not animation.Playing then
    local duration = FlashDuration
    animation.FadeIn:SetDuration(duration)
    animation.FadeOut:SetDuration(duration)
    animation:Play()
    animation.Playing = true
  end
end

function Animations:StopFlash(frame)
  local animation = frame.FlashAnimation
  if animation and animation.Playing then
    animation:Stop()
    animation.Playing = nil;
  end
end

-- function Animations:ShowPlate(frame, target_alpha)
--   local current_alpha = frame:GetAlpha()
--   if floor(abs(current_alpha - target_alpha) * 100) < 1 then return end

--   frame.FadeAnimation = frame.FadeAnimation or {}

--   local animation = frame.FadeAnimation
--   animation.StartAlpha = current_alpha
--   animation.TargetAlpha = target_alpha
--   animation.Duration = ShowPlateDuration
--   animation.Timer = 0
--   animation.Playing = true

--   AnimatedFrames[frame] = true
--   AnimationFrame:Show()
-- end

function Animations:FadePlate(frame, target_alpha)
  -- local current_alpha = frame:GetAlpha()
  -- This check is done before this function is called - maybe not ideal
  -- if floor(abs(current_alpha - target_alpha) * 100) < 1 then return end

  frame.FadeAnimation = frame.FadeAnimation or {}

  local animation = frame.FadeAnimation
  animation.StartAlpha = frame:GetAlpha()
  animation.TargetAlpha = target_alpha
  animation.Duration = FadeToDuration
  animation.Timer = 0
  animation.Playing = true

  AnimatedFrames[frame] = true
  AnimationFrame:Show()
end

function Animations:StopFade(frame)
  if frame.FadeAnimation then
  --frame:SetAlpha(frame.FadeAnimation.TargetAlpha)
    frame.FadeAnimation.Playing = nil
  end
end

function Animations:ScalePlate(frame, target_scale)
  local current_scale = frame:GetScale()
  if floor(abs(current_scale - target_scale) * 100) < 1 then return end

  frame.ScaleAnimation = frame.ScaleAnimation or {}

  local animation = frame.ScaleAnimation
  animation.StartScale = current_scale
  animation.TargetScale = target_scale
  animation.Duration = abs(current_scale - target_scale) * ScaleToDuration
  --print ("Scaled Duration:", current_scale, target_scale, "=>", abs(current_scale - target_scale), "=",animation.Duration)
  animation.Timer = 0
  animation.Playing = true

  AnimatedFrames[frame] = true
  AnimationFrame:Show()
end

function Animations:StopScale(frame)
  if frame.ScaleAnimation then
    --frame.SetScale(frame.ScaleAnimation.TargetScale)
    --SetPlateScale(frame, frame.ScaleAnimation.TargetScale)
    frame.ScaleAnimation.Playing = nil
  end
end

function Animations:HidePlate(frame)
  local show_animation = false

  if Settings.HidePlateFadeOut then
    frame.FadeAnimation = frame.FadeAnimation or {}

    local animation = frame.FadeAnimation
    animation.StartAlpha = frame:GetAlpha()
    animation.TargetAlpha = 0.01
    animation.Duration = HidePlateDuration
    animation.Timer = 0
    animation.Playing = true

    show_animation = true
  end

  if Settings.HidePlateScaleDown then
    frame.ScaleAnimation = frame.ScaleAnimation or {}

    local animation = frame.ScaleAnimation
    animation.StartScale = frame:GetScale()
    animation.TargetScale = 0.3
    animation.Duration = HidePlateDuration
    animation.Timer = 0
    animation.Playing = true

    show_animation = true
  end

  -- Frame is hidden immediately (no scale animation) or after the animation ends
  if show_animation then
    AnimatedFrames[frame] = true
    AnimationFrame:Show()
  end
end

function Animations:UpdateSettings()
  Settings = TidyPlatesThreat.db.profile.Animations

  -- ShowPlateDuration = Settings.ShowPlateDuration
  HidePlateDuration = Settings.HidePlateDuration
  HidePlateFadeOut = Settings.HidePlateFadeOut
  HidePlateScaleDown = Settings.HidePlateScaleDown
  FadeToDuration = Settings.FadeToDuration
  ScaleToDuration = Settings.ScaleToDuration
  FlashDuration = Settings.FlashDuration
end
