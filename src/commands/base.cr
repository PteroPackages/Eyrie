module Eyrie::Commands::Base
  def on_invalid_options(options)
    Log.fatal [
      "Invalid option#{"s" if options.size > 1} '#{options.join("', '")}'",
      "See 'eyrie #{self.name} --help' for more information"
    ]
  end

  def on_missing_arguments(args)
    Log.fatal [
      "Missing required argument#{"s" if args.size > 1} #{args.join(", ")}",
      "See 'eyrie #{self.name} --help' for more information"
    ]
  end
end
