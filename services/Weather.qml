pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick
import QtPositioning

import qs.modules.common

// Weather via Open-Meteo (no API key) + OpenStreetMap Nominatim for geocoding.
// `city` can be a place name ("Batam", "Nongsa, Batam") or raw coordinates ("1.0456,104.0305").
Singleton {
    id: root

    readonly property int fetchInterval: Config.options.bar.weather.fetchInterval * 60 * 1000
    readonly property string city: Config.options.bar.weather.city
    readonly property bool useUSCS: Config.options.bar.weather.useUSCS
    property bool gpsActive: Config.options.bar.weather.enableGPS

    onUseUSCSChanged: root.getData()
    onCityChanged: root.getData()

    property var location: ({
        valid: false,
        lat: 0,
        lon: 0
    })

    // Cached geocoding result so we only look a city up once
    property var geo: ({
        query: "",
        valid: false,
        lat: 0,
        lon: 0,
        name: ""
    })
    property string pendingQuery: ""

    property var data: ({
        uv: 0,
        humidity: 0,
        sunrise: 0,
        sunset: 0,
        windDir: 0,
        wCode: 0,
        city: "",
        wind: "",
        precip: "",
        visib: "",
        press: "",
        temp: "",
        tempFeelsLike: "",
        lastRefresh: ""
    })

    // WMO weather code -> OpenWeather-style condition id (keeps existing icon mapping working)
    readonly property var wmoToOwm: ({
        0: 800, 1: 801, 2: 802, 3: 804,
        45: 741, 48: 741,
        51: 300, 53: 301, 55: 302,
        56: 511, 57: 511,
        61: 500, 63: 501, 65: 502,
        66: 511, 67: 511,
        71: 600, 73: 601, 75: 602, 77: 600,
        80: 520, 81: 521, 82: 522,
        85: 620, 86: 621,
        95: 201, 96: 202, 99: 202
    })

    readonly property var wmoText: ({
        0: "clear sky", 1: "mainly clear", 2: "partly cloudy", 3: "overcast",
        45: "fog", 48: "rime fog",
        51: "light drizzle", 53: "moderate drizzle", 55: "dense drizzle",
        56: "light freezing drizzle", 57: "dense freezing drizzle",
        61: "light rain", 63: "moderate rain", 65: "heavy rain",
        66: "light freezing rain", 67: "heavy freezing rain",
        71: "light snow", 73: "moderate snow", 75: "heavy snow", 77: "snow grains",
        80: "light rain showers", 81: "moderate rain showers", 82: "violent rain showers",
        85: "light snow showers", 86: "heavy snow showers",
        95: "thunderstorm", 96: "thunderstorm with hail", 99: "thunderstorm with heavy hail"
    })

    // "2026-10-27T05:58" (location-local time) -> "5:58:00 AM"
    function fmtLocalIso(iso) {
        if (!iso || iso.indexOf("T") < 0) return "0"
        const parts = iso.split("T")[1].split(":")
        const h = parseInt(parts[0])
        const m = parts[1]
        const h12 = h % 12 === 0 ? 12 : h % 12
        return `${h12}:${m}:00 ${h >= 12 ? "PM" : "AM"}`
    }

    function refineData(data, cityName) {
        const cur = data?.current || {}
        const daily = data?.daily || {}
        let temp = {}

        const code = cur.weather_code ?? 0
        const precipVal = cur.precipitation || 0

        temp.description = root.wmoText[code] || ""
        temp.cr = Math.round((cur.cloud_cover || 0) * 0.8) + "%"
        temp.humidity = (cur.relative_humidity_2m || 0) + "%"
        temp.sunrise = fmtLocalIso(daily.sunrise?.[0])
        temp.sunset = fmtLocalIso(daily.sunset?.[0])
        temp.uv = Math.round(cur.uv_index || 0)
        temp.windDir = cur.wind_direction_10m || 0
        temp.wCode = root.wmoToOwm[code] || 0
        temp.city = cityName || "City"

        if (root.useUSCS) {
            temp.wind = (cur.wind_speed_10m || 0) + " mph"
            temp.precip = precipVal.toFixed(2) + " in"
            temp.visib = ((cur.visibility || 0) / 1609).toFixed(1) + " mi"
            temp.temp = Math.round(cur.temperature_2m || 0) + "°F"
            temp.tempFeelsLike = Math.round(cur.apparent_temperature || 0) + "°F"
        } else {
            temp.wind = (cur.wind_speed_10m || 0) + " m/s"
            temp.precip = precipVal.toFixed(1) + " mm"
            temp.visib = ((cur.visibility || 0) / 1000).toFixed(1) + " km"
            temp.temp = Math.round(cur.temperature_2m || 0) + "°C"
            temp.tempFeelsLike = Math.round(cur.apparent_temperature || 0) + "°C"
        }
        temp.press = Math.round(cur.pressure_msl || 0) + " hPa"

        temp.lastRefresh = DateTime.time + " • " + DateTime.date

        root.data = temp
    }

    function fetchWeather(lat, lon, cityName) {
        const current = [
            "temperature_2m", "apparent_temperature", "relative_humidity_2m",
            "precipitation", "weather_code", "cloud_cover", "pressure_msl",
            "wind_speed_10m", "wind_direction_10m", "visibility", "uv_index"
        ].join(",")

        let url = "https://api.open-meteo.com/v1/forecast?"
        url += `latitude=${lat}&longitude=${lon}`
        url += `&current=${current}`
        url += `&daily=sunrise,sunset&forecast_days=1&timezone=auto`
        url += root.useUSCS
            ? "&temperature_unit=fahrenheit&wind_speed_unit=mph&precipitation_unit=inch"
            : "&temperature_unit=celsius&wind_speed_unit=ms&precipitation_unit=mm"

        weatherFetcher.cityName = cityName
        weatherFetcher.command = ["bash", "-c", `curl -s --max-time 15 "${url}"`]
        weatherFetcher.running = true
    }

    function geocode(query) {
        root.pendingQuery = query
        const url = "https://nominatim.openstreetmap.org/search?format=jsonv2&limit=1&q=" + encodeURIComponent(query)
        geocoder.command = ["bash", "-c", `curl -s --max-time 15 -A "quickshell-weather/1.0" "${url}"`]
        geocoder.running = true
    }

    function getData() {
        // 1) GPS
        if (root.gpsActive && root.location.valid) {
            fetchWeather(root.location.lat, root.location.lon, root.city.trim())
            return
        }

        const query = root.city.trim()
        if (query === "") return

        // 2) Raw "lat,lon" in the city field
        const m = query.match(/^(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)$/)
        if (m) {
            fetchWeather(m[1], m[2], "")
            return
        }

        // 3) Cached geocode
        if (root.geo.valid && root.geo.query === query) {
            fetchWeather(root.geo.lat, root.geo.lon, root.geo.name)
            return
        }

        // 4) Look the place up, then fetch
        geocode(query)
    }

    Component.onCompleted: {
        if (!root.gpsActive) return
        console.info("[WeatherService] Starting GPS service.")
        positionSource.start()
    }

    Process {
        id: geocoder
        command: ["bash", "-c", ""]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.length === 0) return

                try {
                    const results = JSON.parse(text)
                    if (!Array.isArray(results) || results.length === 0) {
                        console.error(`[WeatherService] Could not find "${root.pendingQuery}". Try a nearby larger place or "lat,lon".`)
                        return
                    }

                    const r = results[0]
                    root.geo = {
                        query: root.pendingQuery,
                        valid: true,
                        lat: parseFloat(r.lat),
                        lon: parseFloat(r.lon),
                        name: r.name || root.pendingQuery
                    }
                    root.fetchWeather(root.geo.lat, root.geo.lon, root.geo.name)
                } catch (e) {
                    console.error("[WeatherService] Geocoding parse error:", e.message)
                }
            }
        }
    }

    Process {
        id: weatherFetcher
        property string cityName: ""
        command: ["bash", "-c", ""]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.length === 0) return

                try {
                    const parsedData = JSON.parse(text)

                    if (parsedData.error) {
                        console.error("[WeatherService] API error:", parsedData.reason)
                        return
                    }

                    root.refineData(parsedData, weatherFetcher.cityName)
                } catch (e) {
                    console.error("[WeatherService] JSON parse error:", e.message)
                }
            }
        }
    }

    PositionSource {
        id: positionSource
        updateInterval: root.fetchInterval

        onPositionChanged: {
            if (position.latitudeValid && position.longitudeValid) {
                root.location.lat = position.coordinate.latitude
                root.location.lon = position.coordinate.longitude
                root.location.valid = true
                root.getData()
            } else {
                root.gpsActive = root.location.valid ? true : false
                console.error("[WeatherService] Failed to get GPS location.")
            }
        }

        onValidityChanged: {
            if (!positionSource.valid) {
                positionSource.stop()
                root.location.valid = false
                root.gpsActive = false
                console.error("[WeatherService] Could not acquire valid GPS backend.")
            }
        }
    }

    Timer {
        running: !root.gpsActive
        repeat: true
        interval: root.fetchInterval
        triggeredOnStart: !root.gpsActive
        onTriggered: root.getData()
    }
}
