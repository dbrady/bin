#!/usr/bin/env ruby
# workflow [task|event|time|thing|whatever] - get a checklist of stuff I should (do|be doing) (now|next)

# E.g.
#
# $ workflow bod
# Beginning Of Day
# ----------------
# [ ] Check Slack
# [ ] Check Email
# [ ] Plan Day
# [ ] Check for Pending PR Reviews

# $ workflow eod
# [ ] Check Slack
# [ ] Check for Pending PR Reviews
# [ ] Post Status of Open Tasks to Team

# Ideas:
# workflow hourly - show me regular reminders
# workflow <magic option> - change bod, hourly and eod from "normal" to "I'm on pagerduty, so include monitoring tasks"


class Workflow
  def display_current_workflow
    if bod?
      display_beginning_of_day_list
    elsif eod?
      display_end_of_day_list
    else
      display_midday_list
    end
  end

  def display_beginning_of_day_list
    puts <<~STR
    BOD Workflow
    [ ] Check Slack
    [ ] Check Email
    [ ] Plan Day
    [ ] Check for Pending PR Reviews
    STR
  end

  def display_end_of_day_list
    puts <<~STR
    EOD Workflow
    [ ] Check Slack
    [ ] Check for Pending PR Reviews
    [ ] Post Status of Open Tasks to Team
    STR
  end

  def display_midday_list
    puts <<~STR
    Midday Workflow
    [ ] Check Slack
    [ ] Check for Pending PR Reviews
    STR
  end

  # is it the right time for the beginning of day checklist
  def bod?
    Time.now.hour < 12
  end

  def eod?
    Time.now.hour >= 15
  end
end

if __FILE__ == $0
  # st00pid version-zero implementation
  workflow = Workflow.new
  workflow.display_current_workflow
end
