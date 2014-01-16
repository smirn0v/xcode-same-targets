require 'colorize'
require 'json'
require 'pathname'
require 'set'
require 'xcodeproj'

CONFIG_FILE_NAME=".xcode-same-targets"

def report_error(msg)
    puts "["+"-".red+"] #{msg}"
end

def report_fail(msg)
    report_error(msg)
    exit(1)
end

def report_ok(msg)
    puts "["+"+".green+"] #{msg}"
end

project_paths = Pathname.pwd.children.select { |pn| pn.extname == '.xcodeproj' }

if project_paths.empty? 
    report_fail("No xcode projects found inside current directory")
end

report_fail("No configuration file('#{CONFIG_FILE_NAME}') found") unless File.exist?(CONFIG_FILE_NAME)

report_ok("#{project_paths.first}")

config = JSON.parse(IO.read(CONFIG_FILE_NAME))
exclusive = ->(name,file_ref) { 
   return false unless !config.key?('exclusive') 
   return false unless !config['exclusive'].key?(name)

   for ex_path in config['exclusive'][name] do
       return true if path.end_with?(ex_path)
   end
   return false
}

project = Xcodeproj::Project.open(project_paths.first)

target_files = {}

project.targets.each { |target|

    name = target.name
    target_files[name] = [].to_set

    target.build_phases.each { |bp|
       bp.files.each { |bf|
           target_files[name] << bf.file_ref
       }
    }

}

extra_target_files = {}

target_files.keys.combination(2).each { |t1_name,t2_name|

    extra_target_files[t1_name] ||= [].to_set
    t1_extra = target_files[t1_name] - target_files[t2_name]
    extra_target_files[t1_name].merge(t1_extra)

}

extra_target_files.each { |name,extra|
    unless extra.empty?
        report_error("'#{name}' target has extra files in it")
        extra.each { |el| puts "  * #{el.display_name}" }
    end 
}
