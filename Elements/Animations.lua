---------------------------------------------------------------------------------------------------
-- Arena Widget
---------------------------------------------------------------------------------------------------
local ADDON_NAME, Addon = ...

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- WoW APIs
local CreateFrame = CreateFrame

-- ThreatPlates APIs
local TidyPlatesThreat = TidyPlatesThreat

local Animations = {}

Addon.Animations = Animations

Animations.FLASH_DURATION = 0.4

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
  if frame.Playing then return end

  if not frame.FlashAnimation then
    self:CreateFlashLoop(frame)
  end

  if not frame.Playing then
    frame.FlashAnimation.FadeIn:SetDuration(duration)
    frame.FlashAnimation.FadeOut:SetDuration(duration)
    frame.FlashAnimation:Play()
    frame.FlashAnimation.Playing = true
  end
end

function Animations:StopFlash(frame)
  if frame.FlashAnimation and frame.FlashAnimation.Playing then
    frame.FlashAnimation:Stop()
    frame.FlashAnimation.Playing = nil;
  end
end
