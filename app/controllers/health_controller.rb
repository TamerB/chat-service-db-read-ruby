class HealthController < ApplicationController
    def health
        render plain: 'OK', status: :ok
    end
end
