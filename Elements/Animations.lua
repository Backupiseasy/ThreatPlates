---------------------------------------------------------------------------------------------------
-- Arena Widget
---------------------------------------------------------------------------------------------------
local ADDON_NAME, Addon = ...

---------------------------------------------------------------------------------------------------
-- Imported functions and constants
---------------------------------------------------------------------------------------------------

-- WoW APIs

-- ThreatPlates APIs

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

function Animations:CreateFadeIn(frame)
  frame.FadeInAnimation = frame:CreateAnimationGroup("FadeIn")
  frame.FadeInAnimation.FadeIn = frame.FadeInAnimation:CreateAnimation("ALPHA", "FadeIn")

  frame.FadeInAnimation:SetScript("OnFinished", function(self, requested)
    self:Stop()
    self.Playing = nil
    frame:SetAlpha(self.TargetAlpha)

    -- Workaround: Re-set the backdrop color for the healthbar, so that the correct alpha value is applied
    -- Otherwise, the backdrop's alpha is set to 1 for some unknown reason.
    local backdrop = frame.visual.healthbar.Border
    backdrop:SetBackdropColor(backdrop:GetBackdropColor())
    backdrop = frame.visual.threatborder
    if backdrop:IsShown() then
      backdrop:SetBackdropBorderColor(backdrop:GetBackdropBorderColor())
    end
  end)

  frame.FadeInAnimation:SetScript("OnUpdate", function(self, elapsed)
    -- Workaround: Re-set the backdrop color for the healthbar, so that the correct alpha value is applied
    -- Otherwise, the backdrop's alpha is set to 1 for some unknown reason.
    local backdrop = frame.visual.healthbar.Border
    backdrop:SetBackdropColor(backdrop:GetBackdropColor())
    backdrop = frame.visual.threatborder
    if backdrop:IsShown() then
      backdrop:SetBackdropBorderColor(backdrop:GetBackdropBorderColor())
    end
  end)
end

function Animations:FadeIn(frame, target_alpha, duration)
  if not frame.FadeInAnimation then
    self:CreateFadeIn(frame, target_alpha)
  end

  local animation = frame.FadeInAnimation
  if not frame.Playing then
    animation.FadeIn:SetFromAlpha(frame:GetAlpha())
    animation.FadeIn:SetToAlpha(target_alpha)
    animation.FadeIn:SetDuration(duration)
    animation:Play()
    animation.Playing = true
    animation.TargetAlpha = target_alpha
  end
end

function Animations:StopFadeIn(frame)
  local animation = frame.FadeInAnimation
  if animation and animation.Playing then
    animation:Stop()
    animation.Playing = nil
  end
end

--function Animations:CreateShrink(frame)
--  frame.ShrinkAnimation = frame:CreateAnimationGroup("Scale")
--  frame.ShrinkAnimation.Anim = frame.ShrinkAnimation:CreateAnimation("Scale", "Shrink")
--
--  frame.ShrinkAnimation:SetScript("OnFinished", function(self, requested)
--    self:Stop()
--    self.Playing = nil
--    frame:Hide()
--  end)
--end
--
--function Animations:Shrink(frame, duration)
--  if frame.Playing then return end
--
--  if not frame.ShrinkAnimation then
--    self:CreateShrink(frame)
--  end
--
--  local animation = frame.ShrinkAnimation
--  if not frame.Playing then
--    --animation.Anim:SetFromScale(frame:GetAlpha())
--    animation.Anim:SetScale(0.2, 0.2)
--    animation.Anim:SetDuration(duration)
--    animation:Play()
--    animation.Playing = true
--  end
--end
--
--function Animations:StopShrink(frame)
--  local animation = frame.ShrinkAnimation
--  if animation and animation.Playing then
--    animation:Stop()
--    animation.Playing = nil
--  end
--end
