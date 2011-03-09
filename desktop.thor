# Thor tasks for managing the windows on your OSX desktop
#
# Install with
#
#    thor install desktop.thor

require 'appscript'
require 'osx/cocoa'

class Desktop < Thor
  desc 'launch', 'Launch named applications'
  def launch(*names)
    applications(names).reject(&:is_running?).each do |application|
      puts "Launching #{application.to_s}"
      application.activate
    end
  end

  desc 'quit', 'Quit name applications'
  def quit(*names)
    applications(names).select(&:is_running?).each do |application|
      puts "Quitting #{application.to_s}"
      application.quit
    end
  end

  desc 'split', 'Divide apps into screen e.g. thor desktop:split Textmate 3 Terminal 2'
  def split(*args)
    split_ratios = []
    total_weight = 0

    while !args.empty?
      split_ratios << [args.shift, args.shift.to_i]
      total_weight = total_weight + split_ratios.last.last
    end

    current_weight = 0

    # Assumes split is for main display
    frame = screens[0].visibleFrame
    split_ratios.each do |split_info|
      app_name, weight = split_info.first, split_info.last
      bounds = [
        frame.x + (frame.width * current_weight / total_weight).to_i,
        frame.y,
        frame.x + (frame.width * (current_weight + weight) / total_weight).to_i,
        frame.y + frame.height
      ]
      launch(app_name)
      Appscript.app(app_name).windows.get.each do |window|
        window.bounds.set(bounds)
      end
      current_weight = current_weight + weight
    end
  end

  desc 'move_app_to_display', 'Move named app to display with index'
  def move_app_to_display(app_name, display_index)
    display_index = display_index.to_i
    if screens.size > display_index
      Appscript.app(app_name).windows.get.each do |window|
        shift_window_to_screen(window, screens[display_index])
      end
    end
  end

  private
    def applications(names)
      names.map{ |name| Appscript.app(name) || raise("Cannot find app named #{name}")}
    end

    def screens
      OSX::NSScreen.screens
    end

    def screen_contains_window?(screen, window)
      bounds = window.bounds.get
      frame = screen.visibleFrame
      return bounds[0] >= frame.x && bounds[0] <= (frame.x + frame.width) &&
        bounds[1] >= frame.y && bounds[1] <= (frame.y + frame.height)
    end

    def shift_window_to_screen(window, target_screen)
      source_screen = screens.detect { |s| screen_contains_window?(s, window) }
      if source_screen && source_screen != target_screen
        bounds = window.bounds.get
        x_shift = target_screen.visibleFrame.x - source_screen.visibleFrame.x
        y_shift = source_screen.visibleFrame.y - target_screen.visibleFrame.y # window bounds are measured from the top and screen frames from the bottom
        shifted_bounds = [bounds[0] + x_shift, bounds[1] + y_shift, bounds[2] + x_shift, bounds[3] + y_shift]
        window.bounds.set(shifted_bounds)
      end
    end
end
