clear; clc; close all

s=tf("s");
Gp = 1/((s+2)*(s+4)*(s+6)*(s+8))
k=355
Gpcl =feedback(Gp,k,-1)
p = pole(Gpcl);
%rlocus(Gp)
figure;
%rlocus(Gpcl)
%rltool(Gp)
olpoles = [2 4 6 8];

%% Desired poles
wn = abs(p(3));  %wn of pole
z = 0.5;
dz = 0.5;   %deired zeta
ts = 4/(z*wn) ;   
dts = ts-0.5 ;     %desired ts
dwn = 4/(dz*dts);   %desired wn
re = -z*dwn;
im = dwn*sqrt(1-z^2);
im = im*1i;
dp = re+im;     %desired pole

zero = -5;   %= This is set to -5 per statement of part 2
angles = zeros(length(olpoles),1);
for j = 1:length(angles)
    angles(j)=angle(dp+olpoles(j));
end
angles = angles * 180/pi;

phi = 180-sum(angles)+angle(dp-zero)*180/pi;  %accounting for zero in angle of defeciency

pole = real(dp)-imag(dp)*tand(90-phi); % only needs angle of defeciency as theres only one pole to add

Tlead = -1/zero;
alpha = -1/(Tlead*pole);
Gp = Gp * 355;

gl = (s-zero)/(s-pole);
Kc =1/abs(evalfr(gl*Gp, dp));

Glead =Kc*gl;

rlocus(Glead)

%% Lag compensator

Kp = Kc*zero/pole/(2*4*6*8)*355;
ess = 1/(1+Kp);
ktot = 30/ess-1;
beta = ktot/(Kp);
Tlag = 1000/beta;

zerol = -1/Tlag;
polel=-1/(beta*Tlag);
Kclag = 1;
Glag = Kclag*(s-zerol)/(s-polel);
Gtot = Glag*Glead*Gp;

%evaluating difference in angle
theta1 = abs(angle(evalfr(Glead*Gp, dp)));
theta2 = abs(angle(evalfr(Gtot, dp)));
dtheta = theta2-theta1;

rlocus(Gtot)

figure;
hold on;
step(feedback(Gp,1,-1))
step(feedback(Glead*Gp,1,-1))
step(feedback(Gtot,1,-1))
legend('Gp','Glead','Gtot')
xlim([0,10]);
figure;
hold on;
step(feedback(Gp,1,-1))
step(feedback(Glead*Gp,1,-1))
step(feedback(Gtot,1,-1))
legend('Gp','Glead','Gtot')

figure;
rlocus(feedback(Gtot,1,-1))  %second order approximation is not valid Re(dominant poles)/Re(submissve poles) is not > 10

fprintf('Lead Time Constant (Tlead) = %.4f\n', Tlead);
fprintf('Lead Zero/Pole Ratio (alpha) = %.4f\n', alpha);
fprintf('Compensator Gain (Kc) = %.4f\n', Kc);
fprintf('Lag Time Constant (Tlag) = %.4f\n', Tlag);
fprintf('Lag Zero/Pole Ratio (beta) = %.4f\n', beta);
fprintf('Difference in angles = %.4f\n', dtheta);