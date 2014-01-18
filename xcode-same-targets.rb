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

module Xcodeproj
    class Project
        module Object
            class AbstractObject
                def recursive(&block)
                    if self.respond_to?('recursive_children')
                        recursive_children.each { |chld|
                            block.call(chld) unless chld.is_a?(PBXGroup)
                        }
                    else
                        block.call(self)
                    end
                end
                # corrupted target
                def wrong_parent
                    parent=Xcodeproj::Project::Object::GroupableHelper.parent(self)
                    return parent.is_a?(Xcodeproj::Project::Object::PBXBuildFile)
                end
            end
        end
    end
end

project_paths = Pathname.pwd.children.select { |pn| pn.extname == '.xcodeproj' }

if project_paths.empty? 
    report_fail("No xcode projects found inside current directory.")
end


report_ok("#{project_paths.first}")

config = nil 

unless File.exist?(CONFIG_FILE_NAME)
    report_ok("No configuration file '#{CONFIG_FILE_NAME}' found, will compare all targets.") unless File.exist?(CONFIG_FILE_NAME)
else
    config = JSON.parse(IO.read(CONFIG_FILE_NAME))
end

project = Xcodeproj::Project.open(project_paths.first)

if !config
    config = { "compare-sets" => [ {"targets" => project.targets.map{|t| t.name}} ] }
end

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

report_fail("No compare sets found.") unless config.key?("compare-sets")

should_be_ignored = ->(path, ignores) { 

   ignored = false

   ignores.each { |iregx|
    ignored = path[/#{iregx}/] != nil 
    break if ignored
   }

   return ignored
}

success = true
config['compare-sets'].each { |cs|

    report_fail("All compare sets must contain targets array.") unless cs.key?('targets') && cs['targets'].kind_of?(Array)

    extra = [].to_set

    cs['targets'].permutation(2).each { |t1_name, t2_name|

        report_fail("'#{t1_name}' target not found") unless project.targets.select { |t| t1_name == t.name }.length == 1
        report_fail("'#{t2_name}' target not found") unless project.targets.select { |t| t2_name == t.name }.length == 1

        ignores = []
        ignores.concat(cs['exclusive'][t1_name]) if cs.key?('exclusive') && cs['exclusive'].key?(t1_name)
        ignores.concat(config['exclusive'][t1_name]) if config.key?('exclusive') && config['exclusive'].key?(t1_name)
        ignores.concat(config['exclusive']['*']) if config.key?('exclusive') && config['exclusive'].key?('*')

        t1_extra = target_files[t1_name] - target_files[t2_name]

        t1_extra.reject! { |fr|
            need_reject = false            
            fr.recursive { |cfr|
               need_reject = cfr.wrong_parent || should_be_ignored[cfr.real_path.to_s, ignores]
               break if need_reject
            }
            need_reject
        }

        extra.merge(t1_extra)
    }

    unless extra.empty?
        success = false
        report_error("Conflicting files for [#{cs['targets'].join(', ')}]")
        extra.each { |fr|
            fr.recursive { |cfr|
                puts("    #{cfr.real_path}")
            }
        }
    end
}

report_ok("No conflicts found.") if success

exit(success ? 0 : 1)
