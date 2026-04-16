clear; clc; close all

syms s K
num = sym(1);
%zeros = solve(num);
den = expand((s+2)*(s+4)*(s+6)*(s+8));
poles = solve(den);
g_unc = tf(sym2poly(num),sym2poly(den));

rlocus(g_unc)
zeta = 0.5
sgrid(zeta,[])

K = 354;
num = sym(K);
den = expand((s+2)*(s+4)*(s+6)*(s+8));
CharEq = simplify(den+num);
poles_unc = double(solve(CharEq));
w_n_unc = abs(poles_unc(3))
t_set_unc = 4/(zeta*w_n_unc)

%% Lead Compensator

w_n_des = 4/((t_set_unc - 0.5)*zeta)
Re_des = -zeta*w_n_des
Im_des = w_n_des*sqrt(1 - zeta^2)
leadPole_des = Re_des + Im_des*1i

phi = 180;
for n = 1:length(poles)
    phi = phi - (180/pi)*double(angle(leadPole_des - poles(n)));
end
phi % Angle Defficiency

zeroPhi = (180/pi)*double(angle(leadPole_des))/2 + abs(phi)/2
polePhi = (180/pi)*double(angle(leadPole_des))/2 - abs(phi)/2

leadZero = Re_des - Im_des/tand(zeroPhi)
leadPole = Re_des - Im_des/tand(polePhi)

T_1 = -1/leadZero
gamma = leadPole/leadZero

s = leadPole_des;
num = K;
den = (s+2)*(s+4)*(s+6)*(s+8);
K_c = 1/abs(((s-leadZero)/(s-leadPole))*(num/den))

%% Lag Compensator

lagPole = -0.001;

K_p0 = (K_c*(-leadZero)*K)/(-leadPole*prod(double(-poles),'all'))
err_step = 1/(1+K_p0)
err_step_lag = err_step/30
K_p = 1/err_step_lag - 1
beta = K_p/K_p0
T_2 = 1/(-lagPole*beta)

lagZero = -1/T_2
lagPole

% Check
s = leadPole_des;
ang1 = (180/pi)*abs(angle(K_c*((s-leadZero)/(s-leadPole))*(num/den)));  %evalues angle of poles of lead compensator and G(S)
ang2 = (180/pi)*abs(angle(K_c*((s-leadZero)/(s-leadPole))*((s-lagZero)/(s-lagPole))*(num/den)));     %avalueates angle after lag comp added
d_ang = ang2-ang1   %difference

%% Plot Comparison

syms s
K = 354

figure
num = sym(1);
den = expand((s+2)*(s+4)*(s+6)*(s+8));
g_unc = tf(sym2poly(num),sym2poly(den));
tf_unc = tf(sym2poly(K*num),sym2poly(den+K*num));
rlocus(g_unc)
zeta = 0.5;
sgrid(zeta,[])
title('Root Locus - Uncompensated')

figure
num = sym(K_c*(s-leadZero));
den = expand((s-leadPole)*(s+2)*(s+4)*(s+6)*(s+8));
g_lead = tf(sym2poly(num),sym2poly(den));
tf_lead = tf(sym2poly(K*num),sym2poly(den+K*num));
rlocus(g_lead)
zeta = 0.5;
sgrid(zeta,[])
title('Root Locus - Lead Compensated')

figure
num = sym(K_c*(s-leadZero)*(s-lagZero));
den = expand((s-leadPole)*(s-lagPole)*(s+2)*(s+4)*(s+6)*(s+8));
g_leadlag = tf(sym2poly(num),sym2poly(den));
tf_leadlag = tf(sym2poly(K*num),sym2poly(den+K*num));
rlocus(g_leadlag)
zeta = 0.5;
sgrid(zeta,[])
title('Root Locus - Lead/Lag Compensated')

figure
hold on
step(tf_unc)
stepinfo(tf_unc)
step(tf_lead)
stepinfo(tf_lead)
step(tf_leadlag)
stepinfo(tf_leadlag)
legend('Uncompensated','Lead','Lead/Lag')