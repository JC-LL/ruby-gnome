require 'gtk2'
Gtk.init

class MyButton < Gtk::Button
  type_register("MyButton")

  def initialize(label = nil)
    # XXX: 
    # When type_register() is used.
    # super is equivalent to GLib::Object#initialize.
    super("label" => label)
    @fuga = 0
  end

  # override existing default handler of "clicked" signal.
  def signal_do_clicked(*args)
    puts "MyButton#signal_do_clicked enter"
    #p caller
    super
    puts "MyButton#signal_do_clicked leave"
  end

  # define new signal "hoge"
  signal_new("hoge",                  # name
             GLib::Signal::RUN_FIRST, # flags
             nil,                     # accumulator (XXX: not supported yet)
             GLib::Type["void"],      # return type
             GLib::Type["gint"], GLib::Type["gint"] # parameter types
             )
  # define default handler of "hoge" signal
  def signal_do_hoge(a, b)
    puts "MyButton#signal_do_hoge enter"
    #p caller
    puts "MyButton#signal_do_hoge leave"
  end

  # define new property "fuga"
  install_property(GLib::Param::Int.new("fuga", # name
                                        "Fuga", # nick
                                        "fuga hoge", # blurb
                                        0,     # min
                                        10000, # max
                                        0,     # default
                                        GLib::Param::READABLE |
                                        GLib::Param::WRITABLE))
  # implementation of the property "fuga"
  def fuga
    puts "MyButton#fuga is called"
    @fuga
  end
  def fuga=(arg)
    puts "MyButton#fuga= is called"
    @fuga = arg
    notify("fuga")
  end
end

class MyButton2 < MyButton
  type_register("MyButton2")

  # override default handler of "clicked" signal
  def signal_do_clicked(*args)
    puts "MyButton2#signal_do_clicked enter"
    super(*args)
    puts "MyButton2#signal_do_clicked leave"
  end

  # override default handler of "hoge" signal
  def signal_do_hoge(a, b)
    puts "MyButton2#signal_do_hoge enter"
    #p caller
    super
    puts "MyButton2#signal_do_hoge leave"
  end
end

b = MyButton2.new("Hello")
p b
p b.label
p b.gtype
b.clicked
b.signal_emit("hoge", 1, 2)

b.signal_connect("notify"){|obj, pspec|
  puts "#{b} notify #{pspec}"
}

p b.get_property("fuga")
b.set_property("fuga", 1)
p b.get_property("fuga")

p MyButton2.ancestors
