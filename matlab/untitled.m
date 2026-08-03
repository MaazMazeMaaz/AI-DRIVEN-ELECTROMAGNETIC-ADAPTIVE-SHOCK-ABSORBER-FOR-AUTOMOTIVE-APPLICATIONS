pressure = [1.0 1.1 1.2 1.3 1.4 1.5 1.6 1.7 1.8 1.9 2.0];
temperature = [65.15 70.62 76.2 81.1 85.5 89.5 93.05 96.0 98.45 100.45 102.8];
exp_slope = [0.53 0.55 0.49 0.44 0.40 0.335 0.295 0.245 0.20 0.235 0.212];
calc_slope = [0.62931 0.593457 0.535867 0.497697 0.441719 0.38656 0.342974 0.315647 0.291167 0.280168 0.2563];

figure('Position', [100, 100, 800, 600])

% Graph 1
subplot(2,1,1)
plot(pressure, temperature, 'o-b', 'LineWidth', 1.5)
title('Vapor Pressure Curve (Temperature vs Pressure)')
xlabel('Pressure (bar)')
ylabel('Temperature (°C)')
grid on
legend('Experimental Data')

% Graph 2
subplot(2,1,2)
plot(pressure, exp_slope, 's--r', 'LineWidth', 1.5)
hold on
plot(pressure, calc_slope, 'o-g', 'LineWidth', 1.5)
title('Comparison of Experimental and Theoretical Slopes')
xlabel('Pressure (bar)')
ylabel('Slope (dT/dP)')
grid on
legend('Experimental Slope', 'Theoretical Slope')

sgtitle('Marcet Boiler Experiment')
