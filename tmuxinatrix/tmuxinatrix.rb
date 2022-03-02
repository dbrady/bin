class Tmuxinatrix
  class <<self
    def execute(command)
      puts command if $logging
      system command
    end

    # this returns truthy if the named session has the specified number of windows open
    def tmux_ready?(session, window_count)
      execute "tmux list-sessions | grep -E '^#{session}: #{window_count} windows '"
    end

    def run(session_name, settingses)
      if tmux_ready?(session_name, settingses.size)
        puts "tmux looks ready to start up the #{session_name} session!"
      else
        puts "tmux is either not running a #{session_name} session, or has the wrong number of windows open."
        puts "Before running this script, stop any existing #{session_name} tmux session, open a new terminal and run:"
        puts "  tmux new-session -s #{session_name}"
        puts "Then, hit 'C-j c' #{settingses.size-1} times so you have a grand total of #{settingses.size} windows open."
        puts "Then rerun this script."
        exit 0
      end

      # Sadly this script needs to be run OUTSIDE the tmux session, so this
      # is prerequisite work: open a new terminal and run new-session,
      # rename-session.

      # execute "tmux new-session"
      # execute "tmux rename-session #{session_name}"

      # this leaves you with 1 window open, yay.

      settingses.each.with_index do |settings, index|
        pane = index + 1

        # FIXME: Window creation is problematic. Have to wait for bash to start up and
        # run all my crap before tmux can find the stupid window.

        # if index > 1
        #   # window 1 is already open
        #   execute "tmux new-window -t#{session_name}"
        #   sleep(1) until tmux_ready?(session_name, index)
        # end

        target = "#{session_name}:#{pane}"
        execute %Q|tmux rename-window -t#{target} "#{settings.name}"|

        # Dono why C-m has to be sent on its own line but it does
        execute %Q|tmux send-keys -t#{target} "cd #{settings.folder}"|
        execute %Q|tmux send-keys -t#{target} "C-m"|

        execute %Q|tmux send-keys -t#{target} "#{settings.command}"|
        execute %Q|tmux send-keys -t#{target} "C-m"|
      end
    end
  end
end
