# Forecast App

Rails app that takes a US address (ZIP or something like "Austin, TX"), pulls a weather forecast, caches it for 30 minutes, and tells you whether you're seeing cached data or a fresh pull.

## How I approached it

I started by splitting the work into steps that map cleanly to the requirements: figure out *where* the user is asking about, fetch the weather for that spot, cache it, show it.

When someone submits the form, `AddressZipResolver` handles the address part. If they typed a ZIP, I call Zippopotam.us to get coordinates and a place name. If they typed a city (with or without a state), I use Open-Meteo's geocoding API, limited to US results, and try to pick the right match when they include something like "TX" or "Texas."

After that, the controller redirects to a GET URL — either `?zip=90210` or `?key=coord:30.2672,-97.7431` — so the result page can be refreshed or shared without resubmitting the form. That's a small thing, but it felt like the right Rails habit.

`ForecastLookup` is where caching lives. It checks `Rails.cache` first. On a hit, it returns the stored forecast and sets `from_cache: true`. On a miss, it calls `OpenMeteoClient`, writes the result with a 30-minute expiry, and returns fresh data. The view reads that flag and shows a short message so the user knows what they're looking at.

I didn't add a database table for forecasts. Weather data is ephemeral; caching it in `Rails.cache` (Solid Cache in production) was enough and keeps the app simpler to run.

## Why I made these choices

**Open-Meteo for weather.** I wanted something I could call without signing up for an API key. Open-Meteo is free, returns current conditions and a multi-day forecast in one request, and also has a geocoding endpoint I could reuse for city searches. That covered the base requirement (current temp) and the bonus stuff (high/low, extended outlook) without juggling two different vendors.

**Zippopotam.us for ZIP codes.** Geocoding a ZIP through Open-Meteo would work, but Zippopotam is built exactly for "US ZIP → lat/lng + city name" and the response is tiny. I only use it when the input already looks like a ZIP.

**Plain `Net::HTTP` instead of Faraday or similar.** For three GET calls, pulling in another gem felt like overkill. I wrapped the shared bits — timeouts, JSON parse, error on non-2xx — in a small `HttpJson` module. The weather and geocoding classes stay focused on their own APIs.

**Cache keys by ZIP when possible.** The spec talks about caching by zip code. When the user enters `90210`, the cache key is literally that ZIP. When they search by city and geocoding doesn't give me a ZIP I trust, I fall back to a coordinate-based key (`coord:30.2672,-97.7431`) so the same place still hits the cache on repeat visits. The location label rides along in the cached payload so the page still reads nicely.

**Thin controller, fat services.** `ForecastsController` mostly wires params to service objects and sets instance variables for the view. Validation, HTTP calls, caching, and error messages live in `app/services/`. If I need to change how geocoding works or add tests around caching, I don't have to dig through a bloated controller.

## Code organization

Most of the logic sits in four service files under `app/services/`:

- `address_zip_resolver.rb` — input → coordinates + cache key
- `forecast_lookup.rb` — cache read/write, 30-minute TTL
- `open_meteo_client.rb` — forecast API and shaping the JSON into something the view can use
- `http_json.rb` — shared HTTP helper

I used small `Struct` objects for results (`LookupResult`, `AddressZipResolver::Result`) so success and failure paths are explicit instead of guessing at hash keys. API failures get caught and turned into messages the user actually sees — a bad ZIP shouldn't blow up as a 500.

The UI is a single ERB template with straightforward markup: a definition list for current conditions, a table for the 7-day outlook, and a line at the top that changes depending on cache status. Styling is plain CSS with BEM-ish class names — nothing fancy, but easy to follow.

There's a basic integration test on the forecast form. I kept the external clients in separate classes so I can stub HTTP in unit tests later without much refactoring.

The app ships with Docker and docker-compose if you want to run it containerized. Production uses Solid Cache so entries survive restarts; dev/test use an in-memory store, which is fine for local work.

## Running it

Docker:

```bash
docker compose up --build
```

Then open `http://127.0.0.1:3000/forecasts`.

Attention:
- As this is a test, I've left the master.key in the repository to facilitate evaluation.
- However, in real-world applications, the master.key should not be left in the repository for security reasons.
- I intentionally commented out the .env line in the .gitgnore file to simplify test.

How to test:
 `bin/docker-test`

How to use the app:
- You can inser a zipcode like that `94022` or a addrees like that `Los Altos Hills, CA`

The forecast feature itself doesn't depend on you running migrations — there's no weather model in the database. Solid Cache/Queue use SQLite in production, but that's infrastructure Rails 8 sets up for caching and jobs, not for storing forecasts long-term.
