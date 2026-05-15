# Forecast App

Rails app that takes a US address (ZIP or something like "Austin, TX"), pulls a weather forecast, caches it for 30 minutes, and tells you whether you're seeing cached data or a fresh pull.

## Main technologies

**Application**
- Ruby 4.0.4
- Ruby on Rails 8.1
- Puma (app server)
- ERB views + plain CSS (Propshaft asset pipeline)
- Hotwire (Turbo Rails, Stimulus) — default Rails 8 stack, minimal JS in this app

**Data & caching**
- SQLite (Rails 8 Solid stack: Solid Cache, Solid Queue, Solid Cable in production)
- `Rails.cache` with 30-minute TTL for forecast data

**External APIs**
- [Open-Meteo](https://open-meteo.com/) — weather forecast and US city geocoding
- [Zippopotam.us](https://zippopotam.us/) — US ZIP → coordinates
- Ruby stdlib `Net::HTTP` + JSON (via `HttpJson` helper)

**Testing & quality**
- Minitest (Rails default)
- WebMock (stub HTTP in tests)
- SimpleCov (coverage)
- RuboCop Rails Omakase, Brakeman, bundler-audit

**DevOps**
- Docker & Docker Compose
- Kamal & Thruster (included for deployment; optional for local dev)

## Running it
- Clone project
```ruby
  git clone https://github.com/Diogoazvg/forecast_app.git
```
- I navigate in the local terminal to the project folder path /forecast_app.

Docker:
Run:
```bash
 docker compose up --build -d
or
 docker compose up --build
to see the logs.
```

- Then open `http://127.0.0.1:3000` In your preferred browser.

## How to run tests:

```bash
 bin/docker-test
```

Attention:
- As this is a test, I've left the master.key in the repository to facilitate evaluation.
- However, in real-world applications, the master.key should not be left in the repository for security reasons.
- I intentionally commented out the .env line in the .gitgnore file to simplify test.

How to use the app:
```ruby
- You should insert a zipcode like that "94022"
or
- An addrees like that "Los Altos Hills, CA"
```

<img width="725" height="903" alt="image" src="https://github.com/user-attachments/assets/a342733e-d6da-46b0-88e8-1fe8617dc009" />


## How I approached it

I built a clean, lightweight Rails app that takes a location, figures out where it is, grabs the weather, and caches it. I avoided bloated gems and database tables, keeping the architecture modular and easy to maintain.

Here is how it breaks down:

How it Works (The Flow)
The Route: When someone submits a location, the controller redirects them to a unique GET URL (using coordinates or a ZIP). This prevents form-resubmission bugs and makes the results easy to bookmark or refresh.

The Brains: I used a "thin controller, fat service" setup. The controller just passes data along, while four dedicated service files handle the heavy lifting:

- One to resolve the address (ZIPs go to Zippopotam.us, cities go to Open-Meteo).
- One to handle the cache logic.
- One to fetch and format the weather data.

A tiny custom HTTP helper so I didn't have to pull in a massive gem like Faraday.

The Cache: Weather is temporary, so I didn't create a database model for it. It lives entirely in Rails.cache with a 30-minute expiration. If it's a ZIP search, it caches by ZIP; if it's a city search, it falls back to coordinates.

The UI: A simple, clean ERB page with plain CSS that shows the current temp, a 7-day forecast, and a little note letting the user know if the data is fresh or loaded from the cache.

Why I Made These Choices
Open-Meteo & Zippopotam.us: They are free, fast, and don't require API keys, which makes the app incredibly easy to spin up and test right out of the box.

No Database Overhead: Using Solid Cache (SQLite) for production and an in-memory store for local dev means the app stays lightweight and doesn't require running migrations just to see the weather.

Predictable Data: I used small Ruby Struct objects instead of messy hashes to pass data between services. This keeps errors under control—if an API fails or a user types a bad ZIP, the app handles it gracefully instead of crashing with a 500 error.

What I’d Build Next (If I Had More Time)
Go Global: Right now, it's locked down to the US. I'd open it up to international cities and adjust the cache keys so global postal codes don't collide.

Handle Ambiguity: If someone types "Springfield," the app just guesses the first one it finds. I'd add a screen that lets users choose which Springfield they actually mean.

True Street Addresses: The UI says "address" but it really wants a city or ZIP. I'd either integrate a full geocoding API (like Google or Nominatim) to handle actual street addresses, or update the UI text to be more accurate.

Resilience: I'd add a "stale-while-revalidate" feature so if the weather API goes down, the user still sees the last cached data instead of a hard error screen.
