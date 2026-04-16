clear; clc; close all

syms s

G_plant_sym = 1/(s*(s+8)*(s+30));

M_p = 0.10;
t_p = 0.6;
K_v = 10;

zeta = abs(log(M_p)/sqrt(pi^2 + log(M_p)^2))

omega_B = (pi/(t_p*sqrt(1-zeta^2)))*sqrt((1 - 2*zeta^2) + sqrt(4*zeta^4 - 4*zeta^2 +2))

K = K_v/limit(s*G_plant_sym,s,0)

num = K;
den = s*(s+8)*(s+30);
G_plant = tf(sym2poly(num),sym2poly(den));

figure
bode(G_plant)
grid on
set(gcf,'Position',[100,-500,1000,1000])

phi_max = atand(2*zeta/sqrt(-2*zeta^2+sqrt(1+4*zeta^4)))

omega_C = 0.8*omega_B

x = phi_max - (180 - (138.36 + 5))

alpha = (1-sind(x))/(1+sind(x))

beta = 1/alpha

z_lag = omega_C/10

p_lag = z_lag/beta

G_lag = (beta)*((s+z_lag)/(s+p_lag));

T_1 = 1/(omega_C*sqrt(alpha))

z_lead = 1/T_1

p_lead = z_lead/alpha

G_lead = (1/beta)*((s+z_lead)/(s+p_lead));

num_comp = num*(s+z_lag)*(s+z_lead);
den_comp = (s+p_lag)*(s+p_lead)*den;
G_comp_sym = num_comp/den_comp;
G_comp = tf(sym2poly(num_comp),sym2poly(den_comp));

figure
bode(G_comp)
grid on
set(gcf,'Position',[100,-500,1000,1000])

num_new_plant = num;
den_new_plant = den + num;
G_plant = tf(sym2poly(num_new_plant),sym2poly(den_new_plant));

num_new_comp = num_comp;
den_new_comp = den_comp + num_comp;
G_comp = tf(sym2poly(num_new_comp),sym2poly(den_new_comp));

figure
hold on
step(G_plant)
uncompensated = stepinfo(G_plant)
step(G_comp)
compensated = stepinfo(G_comp)
legend('$\textnormal{Uncompensated}$','$\textnormal{Compensated}$','Interpreter','latex')

G_plant = tf(sym2poly(num_new_plant),sym2poly(s*den_new_plant));
G_comp = tf(sym2poly(num_new_comp),sym2poly(s*den_new_comp));

figure
hold on
step(G_plant)
step(G_comp)
xlim([0,4])
legend('$\textnormal{Uncompensated}$','$\textnormal{Compensated}$','Interpreter','latex')