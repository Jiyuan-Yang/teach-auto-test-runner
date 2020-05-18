class Constant
  if Rails.env == 'production'
    include ::ProductionConstant
  else
    include ::DevelopmentConstant
  end

  ID = '0'.freeze
  OS = 'Ubuntu 19.03'.freeze
end