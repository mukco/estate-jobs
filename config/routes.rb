# frozen_string_literal: true

Estate::Jobs::Engine.routes.draw do
  root to: "internal_jobs#show"
end
