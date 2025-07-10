import 'package:flutter/material.dart';
import 'package:hydrohealth/models/weather_models.dart';
import 'package:hydrohealth/services/weather_service.dart';
import 'package:lottie/lottie.dart';
import 'package:logging/logging.dart';

final Logger _logger = Logger('SuhuKelembapan');

void setupLogging() {
  Logger.root.level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    _logger.info('${record.level.name}: ${record.time}: ${record.message}');
  });
}

class WeatherPage extends StatefulWidget {
  const WeatherPage({super.key});

  @override
  State<WeatherPage> createState() => _WeatherPageState();
}

class _WeatherPageState extends State<WeatherPage> {
  final _weatherService = WeatherService('89e444a457c217e1d37392fe699b8b97');
  Weather? _weather;

  @override
  void initState() {
    super.initState();
    _fetchWeatherForSpecificLocation();
  }

  Future<void> _fetchWeatherForSpecificLocation() async {
    try {
      final weather = await _weatherService.getWeatherForSpecificLocation(
          "Jineng Dalem"); // Use the city name from OpenWeather
      setState(() {
        _weather = weather;
      });
    } catch (e) {
      _logger.info(e);
    }
  }

  String getWeatherAnimation(String? mainCondition) {
    if (mainCondition == null) return 'assets/images/sunny.json';

    switch (mainCondition.toLowerCase()) {
      case 'clouds':
      case 'mist':
      case 'smoke':
      case 'haze':
      case 'dust':
      case 'fog':
        return 'assets/images/cloud.json';
      case 'rain':
      case 'drizzle':
      case 'shower rain':
        return 'assets/images/rain.json';
      case 'thunderstorm':
        return 'assets/images/thunder.json';
      case 'clear':
        return 'assets/images/sunny.json';
      default:
        return 'assets/images/sunny.json';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color.fromRGBO(153, 188, 133, 1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color.fromRGBO(153, 188, 133, 1),
          width: 2,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Lottie.asset(
            getWeatherAnimation(_weather?.mainCondition),
            height: 100,
            width: 100,
          ),
          const SizedBox(width: 10),
          Container(
            height: 100, // Tinggi garis pembatas sesuai tinggi animasi
            width: 2, // Lebar garis pembatas
            color: Colors.white, // Warna garis pembatas
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _weather?.cityName ?? "Loading",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${_weather?.temperature.round()}°C',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Humidity: ${_weather?.humidity ?? 0}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
              Text(
                _weather?.mainCondition ?? "",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
