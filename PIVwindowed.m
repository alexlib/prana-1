function [X,Y,U,V,C,Dia,Corrplanes]=PIVwindowed(im1,im2,tcorr,window,res,zpad,D,Zeromean,Peaklocator,Peakswitch,fracval,saveplane,X,Y,Uin,Vin)
% --- DPIV Correlation ---
imClass = 'double';

%convert input parameters
im1=cast(im1,imClass);
im2=cast(im2,imClass);
L=size(im1);

%convert to gridpoint list
X=X(:);
Y=Y(:);

%preallocate velocity fields and grid format
Nx = window(1);
Ny = window(2);
if nargin <=15
    Uin = zeros(length(X),1,imClass);
    Vin = zeros(length(X),1,imClass);
end

if Peakswitch
    Uin=repmat(Uin(:,1),[1 3]);
    Vin=repmat(Vin(:,1),[1 3]);
    U = zeros(length(X),3,imClass);
    V = zeros(length(X),3,imClass);
    C = zeros(length(X),3,imClass);
    Dia = zeros(length(X),3,imClass);
else
    U = zeros(length(X),1,imClass);
    V = zeros(length(X),1,imClass);
    C = zeros(length(X),1,imClass);
    Dia = zeros(length(X),1,imClass);
end

%sets up extended domain size
if zpad~=0
    Sy=2*Ny;
    Sx=2*Nx;
elseif strcmpi(tcorr,'DCC')
    Sy = res(1,2)+res(2,2)-1;
    Sx = res(1,1)+res(2,1)-1;
else
    Sy=Ny;
    Sx=Nx;
end

%fftshift indicies
fftindy = [ceil(Sy/2)+1:Sy 1:ceil(Sy/2)];
fftindx = [ceil(Sx/2)+1:Sx 1:ceil(Sx/2)];

%window masking filter
sfilt1 = windowmask([Sx Sy],[res(1, 1) res(1, 2)]);
sfilt2 = windowmask([Sx Sy],[res(2, 1) res(2, 2)]);

% sfilt12 = ifft2(fft2(sfilt2).*conj(fft2(sfilt1)));
% 
% keyboard

%correlation plane normalization function (always off)
cnorm = ones(Ny,Nx,imClass);
% s1   = fftn(sfilt1,[Sy Sx]);
% s2   = fftn(sfilt2,[Sy Sx]);
% S21  = s2.*conj(s1);
% 
% %Standard Fourier Based Cross-Correlation
% iS21 = ifftn(S21,'symmetric');
% iS21 = iS21(fftindy,fftindx);
% cnorm = 1./iS21;
% cnorm(isinf(cnorm)) = 0;


%RPC spectral energy filter
spectral = fftshift(energyfilt(Sx,Sy,D,0));

% This is a check for the fractionally weighted correlation.  We won't use
% the spectral filter with FWC or GCC
if strcmpi(tcorr,'FWC')
    frac = fracval;
    spectral = ones(size(spectral));
elseif strcmpi(tcorr,'GCC')
    frac = 1;
    spectral = ones(size(spectral));
else
    frac = 1;
end

% For dynamic rpc flip this switch which allows for dynamic calcuation of
% the spectral function using the diameter of the autocorrelation.
if strcmpi(tcorr,'DRPC')
    dyn_rpc = 1;
else
    dyn_rpc = 0;
end

if saveplane
    Corrplanes=zeros(Sy,Sx,length(X),imClass);
else
    Corrplanes = 0;
end

switch upper(tcorr)
    
    %Standard Cross Correlation
    case 'SCC'
        
        if size(im1,3) == 3
            Gens=zeros(Sy,Sx,3,imClass);
            for n=1:length(X)
                
                %apply the second order discrete window offset
                x1 = X(n) - floor(round(Uin(n))/2);
                x2 = X(n) +  ceil(round(Uin(n))/2);
                
                y1 = Y(n) - floor(round(Vin(n))/2);
                y2 = Y(n) +  ceil(round(Vin(n))/2);
                
                xmin1 = x1- ceil(Nx/2)+1;
                xmax1 = x1+floor(Nx/2);
                xmin2 = x2- ceil(Nx/2)+1;
                xmax2 = x2+floor(Nx/2);
                ymin1 = y1- ceil(Ny/2)+1;
                ymax1 = y1+floor(Ny/2);
                ymin2 = y2- ceil(Ny/2)+1;
                ymax2 = y2+floor(Ny/2);
                
                for r=1:size(im1,3);
                    %find the image windows
                    zone1 = im1( max([1 ymin1]):min([L(1) ymax1]),max([1 xmin1]):min([L(2) xmax1]),r);
                    zone2 = im2( max([1 ymin2]):min([L(1) ymax2]),max([1 xmin2]):min([L(2) xmax2]),r);
                    
                    if size(zone1,1)~=Ny || size(zone1,2)~=Nx
                        w1 = zeros(Ny,Nx);
                        w1( 1+max([0 1-ymin1]):Ny-max([0 ymax1-L(1)]),1+max([0 1-xmin1]):Nx-max([0 xmax1-L(2)]) ) = zone1;
                        zone1 = w1;
                    end
                    if size(zone2,1)~=Ny || size(zone2,2)~=Nx
                        w2 = zeros(Ny,Nx);
                        w2( 1+max([0 1-ymin2]):Ny-max([0 ymax2-L(1)]),1+max([0 1-xmin2]):Nx-max([0 xmax2-L(2)]) ) = zone2;
                        zone2 = w2;
                    end
                    
                    if Zeromean==1
                        zone1=zone1-mean(mean(zone1));
                        zone2=zone2-mean(mean(zone2));
                    end
                    
                    %apply the image spatial filter
                    region1 = (zone1).*sfilt1;
                    region2 = (zone2).*sfilt2;
                    
                    %FFTs and Cross-Correlation
                    f1   = fftn(region1,[Sy Sx]);
                    f2   = fftn(region2,[Sy Sx]);
                    P21  = f2.*conj(f1);
                    
                    %Standard Fourier Based Cross-Correlation
                    G = ifftn(P21,'symmetric');
                    G = G(fftindy,fftindx);
                    Gens(:,:,r) = abs(G);
                end
                G = mean(Gens,3);
                
                %subpixel estimation
                [U(n,:),V(n,:),Ctemp,Dtemp]=subpixel(G,Sx,Sy,cnorm,Peaklocator,Peakswitch,D);
                if Peakswitch
                    C(n,:)=Ctemp;
                    Dia(n,:)=Dtemp;
                end
                if saveplane
                    Corrplanes(:,:,n) = G;
                end
            end
            
        else
            for n=1:length(X)
                
                %apply the second order discrete window offset
                x1 = X(n) - floor(round(Uin(n))/2);
                x2 = X(n) +  ceil(round(Uin(n))/2);
                
                y1 = Y(n) - floor(round(Vin(n))/2);
                y2 = Y(n) +  ceil(round(Vin(n))/2);
                
                xmin1 = x1- ceil(Nx/2)+1;
                xmax1 = x1+floor(Nx/2);
                xmin2 = x2- ceil(Nx/2)+1;
                xmax2 = x2+floor(Nx/2);
                ymin1 = y1- ceil(Ny/2)+1;
                ymax1 = y1+floor(Ny/2);
                ymin2 = y2- ceil(Ny/2)+1;
                ymax2 = y2+floor(Ny/2);
                
                %find the image windows
                zone1 = im1( max([1 ymin1]):min([L(1) ymax1]),max([1 xmin1]):min([L(2) xmax1]));
                zone2 = im2( max([1 ymin2]):min([L(1) ymax2]),max([1 xmin2]):min([L(2) xmax2]));
                
                if size(zone1,1)~=Ny || size(zone1,2)~=Nx
                    w1 = zeros(Ny,Nx);
                    w1( 1+max([0 1-ymin1]):Ny-max([0 ymax1-L(1)]),1+max([0 1-xmin1]):Nx-max([0 xmax1-L(2)]) ) = zone1;
                    zone1 = w1;
                end
                if size(zone2,1)~=Ny || size(zone2,2)~=Nx
                    w2 = zeros(Ny,Nx);
                    w2( 1+max([0 1-ymin2]):Ny-max([0 ymax2-L(1)]),1+max([0 1-xmin2]):Nx-max([0 xmax2-L(2)]) ) = zone2;
                    zone2 = w2;
                end
                
                if Zeromean==1
                    zone1=zone1-mean(mean(zone1));
                    zone2=zone2-mean(mean(zone2));
                end
                
                %apply the image spatial filter
                region1 = (zone1).*sfilt1;
                region2 = (zone2).*sfilt2;
                
                %FFTs and Cross-Correlation
                f1   = fftn(region1,[Sy Sx]);
                f2   = fftn(region2,[Sy Sx]);
                P21  = f2.*conj(f1);
                
                %Standard Fourier Based Cross-Correlation
                G = ifftn(P21,'symmetric');
                G = G(fftindy,fftindx);
                G = abs(G);
                
                %subpixel estimation
                [U(n,:),V(n,:),Ctemp,Dtemp]=subpixel(G,Sx,Sy,cnorm,Peaklocator,Peakswitch,D);
                if Peakswitch
                    C(n,:)=Ctemp;
                    Dia(n,:)=Dtemp;
                end
                if saveplane
                    Corrplanes(:,:,n) = G;
                end
            end
        end
        
    %Direct Cross Correlation
    case 'DCC'
        
        %initialize correlation tensor
        CC = zeros(Sy,Sx,length(X),imClass);
        
        if size(im1,3) == 3
            Gens=zeros(res(1,2)+res(2,2)-1,res(1,1)+res(2,1)-1,3,imClass);
            for n=1:length(X)
                
                %apply the second order discrete window offset
                x1 = X(n) - floor(round(Uin(n))/2);
                x2 = X(n) +  ceil(round(Uin(n))/2);
                
                y1 = Y(n) - floor(round(Vin(n))/2);
                y2 = Y(n) +  ceil(round(Vin(n))/2);
                
                xmin1 = x1- ceil(res(1,1)/2)+1;
                xmax1 = x1+floor(res(1,1)/2);
                xmin2 = x2- ceil(res(2,1)/2)+1;
                xmax2 = x2+floor(res(2,1)/2);
                ymin1 = y1- ceil(res(1,2)/2)+1;
                ymax1 = y1+floor(res(1,2)/2);
                ymin2 = y2- ceil(res(2,2)/2)+1;
                ymax2 = y2+floor(res(2,2)/2);
                
                for r=1:size(im1,3);
                    %find the image windows
                    zone1 = im1( max([1 ymin1]):min([L(1) ymax1]),max([1 xmin1]):min([L(2) xmax1]),r );
                    zone2 = im2( max([1 ymin2]):min([L(1) ymax2]),max([1 xmin2]):min([L(2) xmax2]),r );
                    if size(zone1,1)~=Ny || size(zone1,2)~=Nx
                        w1 = zeros(res(1,2),res(1,1));
                        w1( 1+max([0 1-ymin1]):res(1,2)-max([0 ymax1-L(1)]),1+max([0 1-xmin1]):res(1,1)-max([0 xmax1-L(2)]) ) = zone1;
                        zone1 = w1;
                    end
                    if size(zone2,1)~=Ny || size(zone2,2)~=Nx
                        w2 = zeros(res(2,2),res(2,1));
                        w2( 1+max([0 1-ymin2]):res(2,2)-max([0 ymax2-L(1)]),1+max([0 1-xmin2]):res(2,1)-max([0 xmax2-L(2)]) ) = zone2;
                        zone2 = w2;
                    end
                    
                    if Zeromean==1
                        zone1=zone1-mean(mean(zone1));
                        zone2=zone2-mean(mean(zone2));
                    end
                    
                    %apply the image spatial filter
                    region1 = (zone1);%.*sfilt1;
                    region2 = (zone2);%.*sfilt2;
                                    
                    %correlation done using xcorr2 which is faster then fft's
                    %for strongly uneven windows.
                    %G = xcorr2(region2,region1);
                    % This is a stripped out version of xcorr2
                    G = conv2(region2, rot90(conj(region1),2));
                    
                    region1_std = std(region1(:));
                    region2_std = std(region2(:));
                    if region1_std == 0 || region2_std == 0
                        G = zeros(Sy,Sx);
                    else
                        G = G/std(region1(:))/std(region2(:))/length(region1(:));
                    end
                    Gens(:,:,r) = G;
                    
                    %store correlation matrix
                end
                G = mean(Gens,3);
                
                %subpixel estimation
                [U(n,:),V(n,:),Ctemp,Dtemp]=subpixel(G,Sx,Sy,cnorm,Peaklocator,Peakswitch,D);
                if Peakswitch
                    C(n,:)=Ctemp;
                    Dia(n,:)=Dtemp;
                end
                if saveplane
                    Corrplanes(:,:,n) = G;
                end
            end
        else
            for n=1:length(X)
                
                %apply the second order discrete window offset
                x1 = X(n) - floor(round(Uin(n))/2);
                x2 = X(n) +  ceil(round(Uin(n))/2);
                
                y1 = Y(n) - floor(round(Vin(n))/2);
                y2 = Y(n) +  ceil(round(Vin(n))/2);
                
                xmin1 = x1- ceil(res(1,1)/2)+1;
                xmax1 = x1+floor(res(1,1)/2);
                xmin2 = x2- ceil(res(2,1)/2)+1;
                xmax2 = x2+floor(res(2,1)/2);
                ymin1 = y1- ceil(res(1,2)/2)+1;
                ymax1 = y1+floor(res(1,2)/2);
                ymin2 = y2- ceil(res(2,2)/2)+1;
                ymax2 = y2+floor(res(2,2)/2);
                
                %find the image windows
                zone1 = im1( max([1 ymin1]):min([L(1) ymax1]),max([1 xmin1]):min([L(2) xmax1]) );
                zone2 = im2( max([1 ymin2]):min([L(1) ymax2]),max([1 xmin2]):min([L(2) xmax2]) );
                if size(zone1,1)~=res(1,2) || size(zone1,2)~=res(1,1)
                    w1 = zeros(res(1,2),res(1,1));
                    w1( 1+max([0 1-ymin1]):res(1,2)-max([0 ymax1-L(1)]),1+max([0 1-xmin1]):res(1,1)-max([0 xmax1-L(2)]) ) = zone1;
                    zone1 = w1;
                end
                if size(zone2,1)~=res(2,2) || size(zone2,2)~=res(2,1)
                    w2 = zeros(res(2,2),res(2,1));
                    w2( 1+max([0 1-ymin2]):res(2,2)-max([0 ymax2-L(1)]),1+max([0 1-xmin2]):res(2,1)-max([0 xmax2-L(2)]) ) = zone2;
                    zone2 = w2;
                end

                if Zeromean==1
                    zone1=zone1-mean(zone1(:));
                    zone2=zone2-mean(zone2(:));
                end
                
                %apply the image spatial filter
                region1 = (zone1);%.*sfilt1;
                region2 = (zone2);%.*sfilt2;
                
                %correlation done using xcorr2 which is faster then fft's
                %for strongly uneven windows.
                %G = xcorr2(region2,region1);
                % This is a stripped out version of xcorr2
                G = conv2(region2, rot90(conj(region1),2));
                
                region1_std = std(region1(:));
                region2_std = std(region2(:));
                if region1_std == 0 || region2_std == 0
                    G = zeros(Sy,Sx);
                else
                    G = G/std(region1(:))/std(region2(:))/length(region1(:));
                end

                %subpixel estimation
                [U(n,:),V(n,:),Ctemp,Dtemp]=subpixel(G,Sx,Sy,cnorm,Peaklocator,Peakswitch,D);
                if Peakswitch
                    C(n,:)=Ctemp;
                    Dia(n,:)=Dtemp;
                end
                if saveplane
                    Corrplanes(:,:,n) = G;
                end

                
            end
        end


    %Robust Phase Correlation
    case {'RPC','DRPC','GCC','FWC'}
        
        if size(im1,3) == 3
            Gens=zeros(Sy,Sx,3,imClass);
            for n=1:length(X)
                
                %apply the second order discrete window offset
                x1 = X(n) - floor(round(Uin(n))/2);
                x2 = X(n) +  ceil(round(Uin(n))/2);
                
                y1 = Y(n) - floor(round(Vin(n))/2);
                y2 = Y(n) +  ceil(round(Vin(n))/2);
                
                xmin1 = x1- ceil(Nx/2)+1;
                xmax1 = x1+floor(Nx/2);
                xmin2 = x2- ceil(Nx/2)+1;
                xmax2 = x2+floor(Nx/2);
                ymin1 = y1- ceil(Ny/2)+1;
                ymax1 = y1+floor(Ny/2);
                ymin2 = y2- ceil(Ny/2)+1;
                ymax2 = y2+floor(Ny/2);
                
                for r=1:size(im1,3);
                    %find the image windows
                    zone1 = im1( max([1 ymin1]):min([L(1) ymax1]),max([1 xmin1]):min([L(2) xmax1]),r);
                    zone2 = im2( max([1 ymin2]):min([L(1) ymax2]),max([1 xmin2]):min([L(2) xmax2]),r);
                    if size(zone1,1)~=Ny || size(zone1,2)~=Nx
                        w1 = zeros(Ny,Nx);
                        w1( 1+max([0 1-ymin1]):Ny-max([0 ymax1-L(1)]),1+max([0 1-xmin1]):Nx-max([0 xmax1-L(2)]) ) = zone1;
                        zone1 = w1;
                    end
                    if size(zone2,1)~=Ny || size(zone2,2)~=Nx
                        w2 = zeros(Ny,Nx);
                        w2( 1+max([0 1-ymin2]):Ny-max([0 ymax2-L(1)]),1+max([0 1-xmin2]):Nx-max([0 xmax2-L(2)]) ) = zone2;
                        zone2 = w2;
                    end
                    
                    if Zeromean==1
                        zone1=zone1-mean(mean(zone1));
                        zone2=zone2-mean(mean(zone2));
                    end
                    
                    %apply the image spatial filter
                    region1 = (zone1).*sfilt1;
                    region2 = (zone2).*sfilt2;
                    
                    %FFTs and Cross-Correlation
                    f1   = fftn(region1,[Sy Sx]);
                    f2   = fftn(region2,[Sy Sx]);
                    P21  = f2.*conj(f1);
                    
                    %Phase Correlation
                    W = ones(Sy,Sx);
                    Wden = sqrt(P21.*conj(P21));
                    W(Wden~=0) = Wden(Wden~=0);
                    if frac ~= 1
                        R = P21./(W.^frac); %Apply fractional weighting to the normalization
                    else
                        R = P21./W;
                    end
                    
                    % If DRPC, the calculate the spectral function
                    % dynamically based on the autocorrelation
                    if dyn_rpc
                        CPS = ifftn(Wden,'symmetric');
                        [~,~,~,Drpc]=subpixel(CPS(fftindy,fftindx),Sx,Sy,cnorm,Peaklocator,0,D);
                        spectral = fftshift(energyfilt(Sx,Sy,Drpc/sqrt(2),0));
                    end
                    
                    %Robust Phase Correlation with spectral energy filter
                    G = ifftn(R.*spectral,'symmetric');
                    G = G(fftindy,fftindx);
                    Gens(:,:,r) = abs(G);
                end
                G=mean(Gens,3);
                
                %subpixel estimation
                [U(n,:),V(n,:),Ctemp,Dtemp]=subpixel(G,Sx,Sy,cnorm,Peaklocator,Peakswitch,D);
                if Peakswitch
                    C(n,:)=Ctemp;
                    Dia(n,:)=Dtemp;
                end
                if saveplane
                    Corrplanes(:,:,n) = G;
                end                
            end
            
        else
            for n=1:length(X)
                
                %apply the second order discrete window offset
                x1 = X(n) - floor(round(Uin(n))/2);
                x2 = X(n) +  ceil(round(Uin(n))/2);
                
                y1 = Y(n) - floor(round(Vin(n))/2);
                y2 = Y(n) +  ceil(round(Vin(n))/2);
                
                xmin1 = x1- ceil(Nx/2)+1;
                xmax1 = x1+floor(Nx/2);
                xmin2 = x2- ceil(Nx/2)+1;
                xmax2 = x2+floor(Nx/2);
                ymin1 = y1- ceil(Ny/2)+1;
                ymax1 = y1+floor(Ny/2);
                ymin2 = y2- ceil(Ny/2)+1;
                ymax2 = y2+floor(Ny/2);
                
                %find the image windows
                zone1 = im1( max([1 ymin1]):min([L(1) ymax1]),max([1 xmin1]):min([L(2) xmax1]));
                zone2 = im2( max([1 ymin2]):min([L(1) ymax2]),max([1 xmin2]):min([L(2) xmax2]));
                if size(zone1,1)~=Ny || size(zone1,2)~=Nx
                    w1 = zeros(Ny,Nx);
                    w1( 1+max([0 1-ymin1]):Ny-max([0 ymax1-L(1)]),1+max([0 1-xmin1]):Nx-max([0 xmax1-L(2)]) ) = zone1;
                    zone1 = w1;
                end
                if size(zone2,1)~=Ny || size(zone2,2)~=Nx
                    w2 = zeros(Ny,Nx);
                    w2( 1+max([0 1-ymin2]):Ny-max([0 ymax2-L(1)]),1+max([0 1-xmin2]):Nx-max([0 xmax2-L(2)]) ) = zone2;
                    zone2 = w2;
                end
                
                if Zeromean==1
                    zone1=zone1-mean(mean(zone1));
                    zone2=zone2-mean(mean(zone2));
                end
                
                %apply the image spatial filter
                region1 = (zone1).*sfilt1;
                region2 = (zone2).*sfilt2;
                
                %FFTs and Cross-Correlation
                f1   = fftn(region1,[Sy Sx]);
                f2   = fftn(region2,[Sy Sx]);
                P21  = f2.*conj(f1);
                
                %Phase Correlation
                W = ones(Sy,Sx);
                Wden = sqrt(P21.*conj(P21));
                W(Wden~=0) = Wden(Wden~=0);
                if frac ~= 1
                    R = P21./(W.^frac);%apply factional weighting to the normalization
                else
                    R = P21./W;
                end
                
                % If DRPC, the calculate the spectral function
                % dynamically based on the autocorrelation
                if dyn_rpc
                    CPS = ifftn(Wden,'symmetric');
                    [~,~,~,Drpc]=subpixel(CPS(fftindy,fftindx),Sx,Sy,cnorm,Peaklocator,0,D);
                    spectral = fftshift(energyfilt(Sx,Sy,Drpc/sqrt(2),0));
                end

                %Robust Phase Correlation with spectral energy filter
                G = ifftn(R.*spectral,'symmetric');
                G = G(fftindy,fftindx);
                G = abs(G);
                
                %subpixel estimation
                [U(n,:),V(n,:),Ctemp,Dtemp]=subpixel(G,Sx,Sy,cnorm,Peaklocator,Peakswitch,D);
                if Peakswitch
                    C(n,:)=Ctemp;
                    Dia(n,:)=Dtemp;
                end
                if saveplane
                    Corrplanes(:,:,n) = G;
                end
            end
        end
        
    otherwise
        %throw an error, we shouldn't be here
        error('invalid correlation type')

end

%add DWO to estimation
U = round(Uin)+U;
V = round(Vin)+V;
end