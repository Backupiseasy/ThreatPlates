---------------------------------------------------------------------------------------------------
-- Arena Widget
---------------------------------------------------------------------------------------------------
local ADDON_NAME, Addon = ...

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- Lua APIs
local pairs, next = pairs, next

-- WoW APIs
local CreateFrame, UIParent = CreateFrame, UIParent

-- ThreatPlates APIs

local Animations = Addon.Animations

Animations.FLASH_DURATION = 0.4

---------------------------------------------------------------------------------------------------
-- Animation Function (OnUpdate on a frame)
---------------------------------------------------------------------------------------------------

local AnimationFrame = CreateFrame("Frame", "ThreatPlatesAnimation", UIParent)
local PlatesToWatch = {}

local function AnimationOnUpdate(self, elapsed)
  for frame, info in pairs(PlatesToWatch) do
    --if info.Type == "Alpha" then
      info.FadeTimer = info.FadeTimer + elapsed

      if info.FadeTimer < info.Duration then
        frame:SetAlpha((info.FadeTimer / info.Duration) * (info.TargetAlpha - info.StartAlpha) + info.StartAlpha)
      else
        frame:SetAlpha(info.TargetAlpha)
        PlatesToWatch[frame] = nil
      end
    --end
  end

  if not next(PlatesToWatch) then
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

function Animations:Flash(frame, duration)
  if not frame.FlashAnimation then
    self:CreateFlashLoop(frame)
  end

  local animation = frame.FlashAnimation
  if not animation.Playing then
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

--function Animations:CreateFadeIn(frame)
--  frame.FadeInAnimation = frame:CreateAnimationGroup("FadeIn")
--  frame.FadeInAnimation.FadeIn = frame.FadeInAnimation:CreateAnimation("ALPHA", "FadeIn")
--
--  frame.FadeInAnimation:SetScript("OnFinished", function(self, requested)
--    self:Stop()
--    self.Playing = nil
--    frame:SetAlpha(self.TargetAlpha)
--
--    -- Workaround: Re-set the backdrop color for the healthbar, so that the correct alpha value is applied
--    -- Otherwise, the backdrop's alpha is set to 1 for some unknown reason.
--    local backdrop = frame.visual.healthbar.Background
--    backdrop:SetVertexColor(backdrop:GetVertexColor())
--    backdrop = frame.visual.threatborder
--    if backdrop:IsShown() then
--      backdrop:SetBackdropBorderColor(backdrop:GetBackdropBorderColor())
--    end
--  end)
--
--  frame.FadeInAnimation:SetScript("OnUpdate", function(self, elapsed)
--    -- Workaround: Re-set the backdrop color for the healthbar, so that the correct alpha value is applied
--    -- Otherwise, the backdrop's alpha is set to 1 for some unknown reason.
--    local backdrop = frame.visual.healthbar.Background
--    backdrop:SetVertexColor(backdrop:GetVertexColor())
--    backdrop = frame.visual.threatborder
--    if backdrop:IsShown() then
--      backdrop:SetBackdropBorderColor(backdrop:GetBackdropBorderColor())
--    end
--  end)
--end

--function Animations:FadeIn(frame, target_alpha, duration)
--  if not frame.FadeInAnimation then
--    self:CreateFadeIn(frame, target_alpha)
--  end
--
--  local animation = frame.FadeInAnimation
--  if not frame.Playing then
--    animation.FadeIn:SetFromAlpha(frame:GetAlpha())
--    animation.FadeIn:SetToAlpha(target_alpha)
--    animation.FadeIn:SetDuration(duration)
--    animation:Play()
--    animation.Playing = true
--    animation.TargetAlpha = target_alpha
--  end
--end
--
--function Animations:StopFadeIn(frame)
--  local animation = frame.FadeInAnimation
--  if animation and animation.Playing then
--
--    local r, g, b, a = frame.visual.healthbar.Background:GetVertexColor()
--    if frame.unit.isTarget then
--      print (GetTime(), "Vor Stop: a =>", a)
--    end
--
--    animation:Pause()
--
--    local r, g, b, a = frame.visual.healthbar.Background:GetVertexColor()
--    if frame.unit.isTarget then
--      print (GetTime(), "Nach Stop: a =>", a)
--    end
--
--    frame:SetAlpha(animation.TargetAlpha)
--    --frame:SetAlpha(frame.CurrentAlpha)
--    animation.Playing = nil
--  end
--end

function Animations:FadePlate(frame, target_alpha, duration)
  --local current_alpha = frame:GetAlpha()
  --if floor(abs(current_alpha - target_alpha) * 100) < 1 then return end

  local info = PlatesToWatch[frame]
  if not info then
    info = {}
    PlatesToWatch[frame] = info
  end

  --info.Type = "Alpha"
  info.StartAlpha = frame:GetAlpha()
  info.TargetAlpha = target_alpha
  info.Duration = duration
  info.FadeTimer = 0

  AnimationFrame:Show()
end

function Animations:StopFade(frame)
  local info = PlatesToWatch[frame]
  if info then
    -- frame:SetAlpha(info.TargetAlpha)
    -- frame:SetScale(info.TargetScale)
    PlatesToWatch[frame] = nil
  end
end