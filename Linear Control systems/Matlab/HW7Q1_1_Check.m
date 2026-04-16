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
clpoles = [2 4 6 8];

%% Desired poles
p(1);
wn = abs(p(3)); %Wn of pole at z=0.5 (found by clicking on rlocus)
z = 0.5;
dz = 0.5;   %deired zeta
ts = 4/(z*wn) ;   %ts of normal pole
dts = ts-0.5 ;     %desired ts
dwn = 4/(dz*dts);   %desired wn
re = -z*dwn;    %real part od desired pole
im = dwn*sqrt(1-z^2);    %imaginary part of desired pole
im = im*1i;    
dp = re+im;     %desired pole

%% Lead Compensator
angles = zeros(length(clpoles),1);  %preseting
for j = 1:length(angles)
    angles(j)=angle(dp+clpoles(j));  %sum of angles from poles to find angle of defeciency
end
angles = angles * 180/pi;
phi = 180-sum(angles);     % calulating phi both ways reults in same phi (angle of defeciency)
phi = 180 - angle(evalfr(Gp,dp))*180/pi; %this way is easier

pangle = angle(dp)*180/pi;       %used in calulations
gamma = 90-pangle/2-abs(phi)/2   %angle to zero (see lecture notes)

zero = real(dp)-imag(dp)*tand(gamma);   %= - 1/T 
pole = real(dp)-imag(dp)*tand(gamma+abs(phi)); %=  -1/αT 
T1 = -1/zero;    %lead Time constant
alpha = -1/(T1*pole);    %alpha
Gp = Gp * 355;            %becasue at k=355 z=0.5 G(s) should be using this gain
gl = (s-zero)/(s-pole);        %lead compensator without Kc
Kc =1/abs(evalfr(gl*Gp, dp));      %solving for Kc

Glead =Kc*gl;     %lead compensator tf



%% Lag compensator

Kp = Kc*zero/pole/(2*4*6*8)*355    %finding Kp using final value formula
ess = 1/(1+Kp);     %steady state error
ktot = 30/ess-1;       %found using desired steady state error = ess/30
beta = ktot/(Kp);   %beta
T2 = 1000/beta;    %Time constant of lag compensator

zerol = -1/T2;   %lag zero
polel=-1/(beta*T2);     %lag pole
Kclag = 1;         %set to 1 as stated in hw
Glag = Kclag*(s-zerol)/(s-polel);        %Tf of lag compensator

Gtot = Glag*Glead*Gp;     %Gc*G(S)

%finding difference in angle
theta1 = abs(angle(evalfr(Glead*Gp, dp)));  %evalues angle of poles of lead compensator and G(S)
theta2 = abs(angle(evalfr(Gtot, dp)));     %avalueates angle after lag comp added
dtheta = theta2-theta1   %difference

%plotting
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

fprintf('Lead Time Constant (Tlead) = %.4f\n', T1);
fprintf('Lead Zero/Pole Ratio (alpha) = %.4f\n', alpha);
fprintf('Compensator Gain (Kc) = %.4f\n', Kc);
fprintf('Lag Time Constant (Tlag) = %.4f\n', T2);
fprintf('Lag Zero/Pole Ratio (beta) = %.4f\n', beta);
fprintf('Difference in angles = %.4f\n', dtheta);