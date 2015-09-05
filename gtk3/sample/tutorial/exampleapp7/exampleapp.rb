# Copyright (C) 2015  Ruby-GNOME2 Project Team
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA
#
# Original:
#   * URL: https://git.gnome.org/browse/gtk+/tree/examples/application7/exampleapp.c
#   * URL: https://git.gnome.org/browse/gtk+/tree/examples/application7/exampleappwin.c
#   * License: LGPL 2

require "gtk3"

require "fileutils"

current_path = File.expand_path(File.dirname(__FILE__))
gresource_bin = "#{current_path}/exampleapp.gresource"
gresource_xml = "#{current_path}/exampleapp.gresource.xml"

system("glib-compile-resources",
       "--target", gresource_bin,
       "--sourcedir", current_path,
       gresource_xml)

gschema_bin = "#{current_path}/gschemas.compiled"
gschema_xml = "#{current_path}/org.gtk.exampleapp.gschema.xml"

system("glib-compile-schemas", current_path)


at_exit do
  FileUtils.rm_f([gresource_bin, gschema_bin])
end

resource = Gio::Resource.load(gresource_bin)
Gio::Resources.register(resource)

ENV["GSETTINGS_SCHEMA_DIR"] = current_path 

class ExampleAppPrefs < Gtk::Dialog
  type_register

  class << self
    def init
      set_template(:resource => "/org/gtk/exampleapp/prefs.ui")
      bind_template_child("font")
      bind_template_child("transition")
    end
  end

  def initialize(args)
    parent = args[:transient_for]
    bar = args[:use_header_bar]
    super(:transient_for => parent, :use_header_bar => 1)
    settings = Gio::Settings.new("org.gtk.exampleapp")
    settings.bind("font",
                  font,
                  "font",
                  Gio::SettingsBindFlags::DEFAULT)
    settings.bind("transition",
                  transition,
                  "active-id",
                  Gio::SettingsBindFlags::DEFAULT)
  end
end

class ExampleAppWindow < Gtk::ApplicationWindow
  type_register
  class << self
    def init
      set_template(:resource => "/org/gtk/exampleapp/window.ui")
      bind_template_child("stack")
      bind_template_child("search")
      bind_template_child("searchbar")
      set_connect_func do |name|
        method(name)
      end
      private

      def search_text_changed(*args)
        search_entry = args[0]
        text = search_entry.text
        return if text.empty?

        win = search_entry.toplevel
        tab = win.stack.visible_child
        view = tab.child
        buffer = view.buffer
        range = buffer.start_iter.forward_search(text, Gtk::TextSearchFlags::CASE_INSENSITIVE)
        return unless range
        buffer.select_range(range[0], range[1])
        view.scroll_to_iter(range[0], 0.0, false, 0.0, 0.0)
      end
    
      def visible_child_changed(*args)
        stack = args[0]
        return if stack.in_destruction
        win = stack.toplevel
        win.searchbar.set_search_mode(false)
      end
      
    end
  end

  def initialize(application)
    super(:application => application)
    @settings = Gio::Settings.new("org.gtk.exampleapp")
    @settings.bind("transition",
                  stack,
                  "transition-type",
                  Gio::SettingsBindFlags::DEFAULT)
    search.bind_property("active", searchbar, "search-mode-enabled", :bidirectional)
  end

  def open(file)
    basename = file.basename

    scrolled = Gtk::ScrolledWindow.new
    scrolled.show
    scrolled.set_hexpand(true)
    scrolled.set_vexpand(true)

    view = Gtk::TextView.new
    view.set_editable(false)
    view.set_cursor_visible(false)
    view.show
    scrolled.add(view)

    stack.add_titled(scrolled, basename, basename)

    stream = file.read
    buffer = view.buffer
    buffer.text = stream.read
    tag = buffer.create_tag() 
    @settings.bind("font", tag, "font", Gio::SettingsBindFlags::DEFAULT)
    buffer.apply_tag(tag, buffer.start_iter, buffer.end_iter)
    search.set_sensitive(true)
  end
end

class ExampleApp < Gtk::Application
  def initialize
    super("org.gtk.exampleapp", :handles_open)

    signal_connect "startup" do |application|
      quit_accels = ["<Ctrl>Q"]
      action = Gio::SimpleAction.new("quit")
      action.signal_connect("activate") do |_action, _parameter|
        application.quit
      end
      application.add_action(action)
      application.set_accels_for_action("app.quit", quit_accels)

      action = Gio::SimpleAction.new("preferences")
      action.signal_connect("activate") do |_action, _parameter|
        win = application.windows.first
        prefs = ExampleAppPrefs.new(:transient_for => win,
                                    :use_header_bar => true)
        prefs.present
      end
      application.add_action(action)

      builder = Gtk::Builder.new(:resource => "/org/gtk/exampleapp/app-menu.ui")
      app_menu = builder.get_object("appmenu")
      application.set_app_menu(app_menu)
    end

    signal_connect "activate" do |application|
      window = ExampleAppWindow.new(application)
      window.present
    end

    signal_connect "open" do |application, files, hint|
      windows = application.windows
      win = nil
      unless windows.empty?
        win = windows.first
      else
        win = ExampleAppWindow.new(application)
      end

      files.each { |file| win.open(file) }

      win.present
    end

  end
end

app = ExampleApp.new

puts app.run([$0] + ARGV)
