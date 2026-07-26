//+------------------------------------------------------------------+
//|                                                         Beta.mqh |
//|                             Copyright 2000-2026, MetaQuotes Ltd. |
//|                                                     www.mql5.com |
//+------------------------------------------------------------------+
#include "Math.mqh"

//+------------------------------------------------------------------+
//| Beta density function (PDF)                                      |
//+------------------------------------------------------------------+
//| The function returns the probability density function of         |
//| the Beta distribution with shape parameters a and b.             |
//|                                                                  |
//|             f(x,a,b)= (1/Beta(a,b))*x^(a-1)*(1-x)^(b-1)          |
//| Arguments:                                                       |
//| x          : Random variable                                     |
//| a          : First shape parameter (a>0)                         |
//| b          : Second shape parameter (b>0)                        |
//| log_mode   : Logarithm mode flag, if true it returns Log values  |
//| error_code : Variable for error code                             |
//|                                                                  |
//| Return value:                                                    |
//| The probability density evaluated at x.                          |
//+------------------------------------------------------------------+
double MathProbabilityDensityBeta(const double x,const double a,const double b,const bool log_mode,int &error_code)
  {
//--- check NaN
   if(!MathIsValidNumber(x) || !MathIsValidNumber(a) || !MathIsValidNumber(b))
     {
      error_code=ERR_ARGUMENTS_NAN;
      return QNaN;
     }
//--- a and b must be positive
   if(a<=0.0 || b<=0.0)
     {
      error_code=ERR_ARGUMENTS_INVALID;
      return QNaN;
     }

   error_code=ERR_OK;
//--- check x range
   if(x<=0.0 || x>=1.0)
      return TailLog0(true,log_mode);

   double log_result=(a-1.0)*MathLog(x)+(b-1.0)*MathLog(1.0-x)-MathBetaLog(a,b);
//--- return log beta density
   if(log_mode==true)
      return log_result;
//--- return beta density
   return MathExp(log_result);
  }
//+------------------------------------------------------------------+
//| Beta density function (PDF)                                      |
//+------------------------------------------------------------------+
//| The function returns the probability density function of         |
//| the Beta distribution with shape parameters a and b.             |
//|                                                                  |
//|             f(x,a,b)= (1/Beta(a,b))*x^(a-1)*(1-x)^(b-1)          |
//| Arguments:                                                       |
//| x          : Random variable                                     |
//| a          : First shape parameter (a>0)                         |
//| b          : Second shape parameter (b>0)                        |
//| error_code : Variable for error code                             |
//|                                                                  |
//| Return value:                                                    |
//| The probability density evaluated at x.                          |
//+------------------------------------------------------------------+
double MathProbabilityDensityBeta(const double x,const double a,const double b,int &error_code)
  {
   return MathProbabilityDensityBeta(x,a,b,false,error_code);
  }
//+------------------------------------------------------------------+
//| Beta density function (PDF)                                      |
//+------------------------------------------------------------------+
//| The function calculates the probability density function of the  |
//| Beta distribution with shape parameters a and b for values in    |
//| x[] array.                                                       |
//|                                                                  |
//| Arguments:                                                       |
//| x          : Array with random variables                         |
//| a          : First shape parameter (a>0)                         |
//| b          : Second shape parameter (b>0)                        |
//| log_mode   : Logarithm mode flag,if true it calculates Log values|
//| result     : Array with calculated values                        |
//|                                                                  |
//| Return value:                                                    |
//| true if successful, otherwise false.                             |
//+------------------------------------------------------------------+  
bool MathProbabilityDensityBeta(const double &x[],const double a,const double b,const bool log_mode,double &result[])
  {
//--- check NaN
   if(!MathIsValidNumber(a) || !MathIsValidNumber(b))
      return false;
//--- a and b must be positive
   if(a<=0.0 || b<=0.0)
      return false;

   int data_count=ArraySize(x);
   if(data_count==0)
      return false;

   int error_code=0;
   ArrayResize(result,data_count);
   for(int i=0; i<data_count; i++)
     {
      double x_arg=x[i];

      if(!MathIsValidNumber(x_arg))
         return false;

      if(x_arg<=0.0 || x_arg>=1.0)
         result[i]=TailLog0(true,log_mode);
      else
        {
         double log_result=(a-1.0)*MathLog(x_arg)+(b-1.0)*MathLog(1.0-x_arg)-MathBetaLog(a,b);
         if(log_mode==true)
            result[i]=log_result;
         else
            result[i]=MathExp(log_result);
        }
     }
   return true;
  }
//+------------------------------------------------------------------+
//| Beta density function (PDF)                                      |
//+------------------------------------------------------------------+
//| The function calculates the probability density function of the  |
//| Beta distribution with shape parameters a and b for values in    |
//| x[] array.                                                       |
//|                                                                  |
//| Arguments:                                                       |
//| x          : Array with random variables                         |
//| a          : First shape parameter (a>0)                         |
//| b          : Second shape parameter (b>0)                        |
//| result     : Array with calculated values                        |
//|                                                                  |
//| Return value:                                                    |
//| true if successful, otherwise false.                             |
//+------------------------------------------------------------------+  
bool MathProbabilityDensityBeta(const double &x[],const double a,const double b,double &result[])
  {
   return MathProbabilityDensityBeta(x,a,b,false,result);
  }
//+------------------------------------------------------------------+
//| Beta cumulative distribution function (CDF)                      |
//+------------------------------------------------------------------+
//| The function returns the cumulative distribution function of     |
//| the Beta distribution with shape parameters a and b, evaluated   |
//| at x.                                                            |
//|                                                                  |
//| Arguments:                                                       |
//| x          : The desired quantile                                |
//| a          : First shape parameter (a>0)                         |
//| b          : Second shape parameter (b>0)                        |
//| tail       : Flag to calculate lower tail                        |
//| log_mode   : Logarithm mode flag,if true it calculates Log values|
//| error_code : Variable for error code                             |
//|                                                                  |
//| Return value:                                                    |
//| The value of the Beta cumulative distribution function with      |
//| shape parameters a and b, evaluated at x.                        |
//+------------------------------------------------------------------+
double MathCumulativeDistributionBeta(const double x,const double a,const double b,const bool tail,const bool log_mode,int &error_code)
  {
//--- check NaN
   if(!MathIsValidNumber(x) || !MathIsValidNumber(a) || !MathIsValidNumber(b))
     {
      error_code=ERR_ARGUMENTS_NAN;
      return QNaN;
     }
//--- a and b must be positive
   if(a<=0.0 || b<=0.0)
     {
      error_code=ERR_ARGUMENTS_INVALID;
      return QNaN;
     }

   error_code=ERR_OK;
//--- check x range
   if(x<=0.0)
      return TailLog0(tail,log_mode);
   if(x>=1.0)
      return TailLog1(tail,log_mode);
//--- calculate probability and take into account round-off errors
   double cdf=MathMin(MathBetaIncomplete(x,a,b),1.0);
//--- return result depending on arguments
   return TailLogValue(cdf,tail,log_mode);
  }
//+------------------------------------------------------------------+
//| Beta cumulative distribution function (CDF)                      |
//+------------------------------------------------------------------+
//| The function returns the cumulative distribution function of     |
//| the Beta distribution with shape parameters a and b, evaluated   |
//| at x.                                                            |
//|                                                                  |
//| Arguments:                                                       |
//| x          : The desired quantile                                |
//| a          : First shape parameter (a>0)                         |
//| b          : Second shape parameter (b>0)                        |
//| error_code : Variable for error code                             |
//|                                                                  |
//| Return value:                                                    |
//| The value of the Beta cumulative distribution function with      |
//| shape parameters a and b, evaluated at x.                        |
//+------------------------------------------------------------------+
double MathCumulativeDistributionBeta(const double x,const double a,const double b,int &error_code)
  {
   return MathCumulativeDistributionBeta(x,a,b,true,false,error_code);
  }
//+------------------------------------------------------------------+
//| The Beta cumulative distribution function (CDF)                  |
//+------------------------------------------------------------------+
//| The function returns the cumulative distribution function of     |
//| the Beta distribution with shape parameters a and b for values   |
//| in x[] array                                                     |
//|                                                                  |
//| Arguments:                                                       |
//| x          : Array with random variables                         |
//| a          : First shape parameter (a>0)                         |
//| b          : Second shape parameter (b>0)                        |
//| tail       : Flag to calculate lower tail                        |
//| log_mode   : Logarithm mode flag,if true it calculates Log values|
//| error_code : Variable for error code                             |
//|                                                                  |
//| Return value:                                                    |
//| true if successful, otherwise false.                             |
//+------------------------------------------------------------------+
bool MathCumulativeDistributionBeta(const double &x[],const double a,const double b,const bool tail,const bool log_mode,double &result[])
  {
//--- check NaN
   if(!MathIsValidNumber(a) || !MathIsValidNumber(b))
      return false;
//--- a and b must be positive
   if(a<=0.0 || b<=0.0)
      return false;

   int data_count=ArraySize(x);
   if(data_count==0)
      return false;

   int error_code=0;
   ArrayResize(result,data_count);
   for(int i=0; i<data_count; i++)
     {
      double x_arg=x[i];
      if(MathIsValidNumber(x_arg))
        {
         if(x_arg<=0.0)
            result[i]=TailLog0(tail,log_mode);
         if(x_arg>=1.0)
            result[i]=TailLog1(tail,log_mode);
         else
           {
            //--- calculate probability and take into account round-off errors
            double cdf=MathMin(MathBetaIncomplete(x_arg,a,b),1.0);
            //--- return result depending on arguments
            result[i]=TailLogValue(cdf,tail,log_mode);
           }
        }
      else
         return false;
     }
   return(true);
  }
//+------------------------------------------------------------------+
//| Beta cumulative distribution function (CDF)                      |
//+------------------------------------------------------------------+
//| The function calculates the cumulative distribution function of  |
//| the Beta distribution with shape parameters a and b for values   |
//| in x[] array.                                                    |
//|                                                                  |
//| Arguments:                                                       |
//| x          : Array with random variables                         |
//| a          : First shape parameter (a>0)                         |
//| b          : Second shape parameter (b>0)                        |
//| error_code : Variable for error code                             |
//|                                                                  |
//| Return value:                                                    |
//| true if successful, otherwise false.                             |
//+------------------------------------------------------------------+
bool MathCumulativeDistributionBeta(const double &x[],const double a,const double b,double &result[])
  {
   return MathCumulativeDistributionBeta(x,a,b,true,false,result);
  }
//+------------------------------------------------------------------+
//| Beta distribution quantile function (inverse CDF)                |
//+------------------------------------------------------------------+
//| The function returns the inverse cumulative distribution         |
//| function of the Beta distribution with shape parameters a and b  |
//| for the desired probability.                                     |
//|                                                                  |
//| Arguments:                                                       |
//| probability : The desired probability                            |
//| a           : First shape parameter (a>0)                        |
//| b           : Second shape parameter (b>0)                       |
//| tail        : Flag to calculate lower tail                       |
//| log_mode    : Logarithm mode flag,if true calculates Log values  |
//| error_code  : Variable for error code                            |
//|                                                                  |
//| Return value:                                                    |
//| The value of the inverse cumulative distribution function of     |
//| the Beta distribution with shape parameters a and b.             |
//+------------------------------------------------------------------+
double MathQuantileBeta(const double probability,const double a,const double b,const bool tail,const bool log_mode,int &error_code)
  {
//--- check parameters
   if(!MathIsValidNumber(a) || !MathIsValidNumber(b))
     {
      error_code=ERR_ARGUMENTS_NAN;
      return QNaN;
     }
//--- a and b must be positive
   if(a<=0.0 || b<=0.0)
     {
      error_code=ERR_ARGUMENTS_INVALID;
      return QNaN;
     }
//--- calculate probability
   double prob=0.0;
   if(!MathCheckProbabilityInput(probability,tail,log_mode,prob,error_code))
      return QNaN;

//--- check probabilty
   if(prob==0.0)
      return 0.0;
   if(prob==1.0)
      return 1.0;

   int err_code=ERR_OK;
   double lo=0.0;
   double hi=1.0;
   const int max_iterations=200;
   const double abs_tol=1e-14;
   const double rel_tol=1e-14;

   for(int i=0;i<max_iterations;i++)
     {
      double mid=0.5*(lo+hi);
      double cdf=MathCumulativeDistributionBeta(mid,a,b,true,false,err_code);

      if(err_code!=ERR_OK || !MathIsValidNumber(cdf))
        {
         error_code=ERR_NON_CONVERGENCE;
         return QNaN;
        }

      if(cdf<prob)
         lo=mid;
      else
         hi=mid;

      if(MathBisectionConverged(lo,hi,abs_tol,rel_tol))
        {
         error_code=ERR_OK;
         return 0.5*(lo+hi);
        }
     }

   error_code=ERR_OK;
   return 0.5*(lo+hi);
  }
//+------------------------------------------------------------------+
//| Beta distribution quantile function (inverse CDF)                |
//+------------------------------------------------------------------+
//| The function returns the inverse cumulative distribution         |
//| function of the Beta distribution with shape parameters a and b  |
//| for the desired probability.                                     |
//|                                                                  |
//| Arguments:                                                       |
//| probability : The desired probability                            |
//| a           : First shape parameter (a>0)                        |
//| b           : Second shape parameter (b>0)                       |
//| error_code  : Variable for error code                            |
//|                                                                  |
//| Return value:                                                    |
//| The value of the inverse cumulative distribution function        |
//| of the Beta distribution with shape parameters a and b.          |
//+------------------------------------------------------------------+
double MathQuantileBeta(const double probability,const double a,const double b,int &error_code)
  {
   return MathQuantileBeta(probability,a,b,true,false,error_code);
  }
//+------------------------------------------------------------------+
//| Beta distribution quantile function (inverse CDF)                |
//+------------------------------------------------------------------+
//| The function calculates the the inverse cumulative distribution  |
//| function of the Beta distribution with shape parameters a and b  |
//| for the probability values from probability[] array.             |
//|                                                                  |
//| Arguments:                                                       |
//| probability : Array with probability values                      |
//| a           : First shape parameter (a>0)                        |
//| b           : Second shape parameter (b>0)                       |
//| tail        : Lower tail flag (lower tail of probability used)   |
//| log_mode    : Logarithm mode flag (log probability used)         |
//| result      : Output array with quantile values                  |
//|                                                                  |
//| Return value:                                                    |
//| true if successful, otherwise false.                             |
//+------------------------------------------------------------------+ 
bool MathQuantileBeta(const double &probability[],const double a,const double b,const bool tail,const bool log_mode,double &result[])
  {
   int data_count=ArraySize(probability);
   if(data_count<=0)
      return(false);

   if(ArrayResize(result,data_count)!=data_count)
      return(false);

   int error_code=ERR_OK;
   for(int i=0;i<data_count;i++)
     {
      result[i]=MathQuantileBeta(probability[i],a,b,tail,log_mode,error_code);
      if(error_code!=ERR_OK || !MathIsValidNumber(result[i]))
         return(false);
     }

   return(true);
  }
//+------------------------------------------------------------------+
//| Beta distribution quantile function (inverse CDF)                |
//+------------------------------------------------------------------+
//| The function calculates the the inverse cumulative distribution  |
//| function of the Beta distribution with shape parameters a and b  |
//| for the probability values from probability[] array.             |
//|                                                                  |
//| Arguments:                                                       |
//| probability : Array with probability values                      |
//| a           : First shape parameter (a>0)                        |
//| b           : Second shape parameter (b>0)                       |
//| result      : Output array with quantile values                  |
//|                                                                  |
//| Return value:                                                    |
//| true if successful, otherwise false.                             |
//+------------------------------------------------------------------+ 
bool MathQuantileBeta(const double &probability[],const double a,const double b,double &result[])
  {
   return MathQuantileBeta(probability,a,b,true,false,result);
  }
//+------------------------------------------------------------------+
//| Random variate from the Beta distribution                        |
//+------------------------------------------------------------------+
//| The function returns a single random deviate from the Beta       |
//| distribution with parameters a and b.                            |
//|                                                                  |
//| Arguments:                                                       |
//| a           : First shape parameter (a>0)                        |
//| b           : Second shape parameter (b>0)                       |
//|                                                                  |
//| Return value:                                                    |
//| The random value with Beta distribution.                         |
//|                                                                  |
//| Reference:                                                       |
//| Russell Cheng,                                                   |
//| "Generating Beta Variates with Nonintegral Shape Parameters",    |
//| Communications of the ACM,                                       |
//| Volume 21, Number 4, April 1978, pages 317-322.                  |
//|                                                                  |
//| Original FORTRAN77 version by Barry Brown, James Lovato.         |
//| C version by John Burkardt.                                      |
//+------------------------------------------------------------------+
double MathRandomBeta(const double a,const double b)
  {
   const double log4 = MathLog(4);
   const double log5 = MathLog(5);
   double a1,b1,alpha,beta,gamma,delta,r,s,u1,u2,v,y,z;
   double w=0.0;
   double value=0;
//---
   if(1.0<a && 1.0<b)
     {
      //--- algorithm BB
      a1 = MathMin(a,b);
      b1 = MathMax(a,b);
      alpha= a1+b1;
      beta = MathSqrt((alpha-2.0)/(2.0*a1*b1-alpha));
      gamma= a1+1.0/beta;
      //---
      for(;;)
        {
         u1 = MathRandomNonZero();
         u2 = MathRandomNonZero();

         if(u1!=1.0)
            v=beta*MathLog(u1/(1.0-u1));
         else
            v=0.0;

         w=a1*MathExp(v);

         z = u1*u1*u2;
         r = gamma*v - log4;
         s = a1+r-w;

         if(5.0*z<=s+1.0+log5)
            break;

         double t=MathLog(z);
         if(t<=s)
            break;

         if(t<=(r+alpha*MathLog(alpha/(b1+w))))
            break;
        }
     }
   else
     {
      //--- algorithm BC
      a1 = MathMax(a,b);
      b1 = MathMin(a,b);
      alpha=a1+b1;
      beta =1.0/b1;
      delta=1.0+a1-b1;
      double k1=delta*(1.0/72.0+b1/24.0)/(a1/b1-7.0/9.0);
      double k2=0.25+(0.5+0.25/delta)*b1;

      for(;;)
        {
         u1 = MathRandomNonZero();
         u2 = MathRandomNonZero();

         if(u1<0.5)
           {
            y = u1*u2;
            z = u1*y;

            if(k1<=0.25*u2+z-y)
               continue;
           }
         else
           {
            z=u1*u1*u2;

            if(z<=0.25)
              {
               if(u1!=1.0)
                  v=beta*MathLog(u1/(1.0-u1));
               else
                  v=0.0;

               w=a1*MathExp(v);

               if(a==a1)
                  value=w/(b1+w);
               else
                  value=b1/(b1+w);

               return value;
              }

            if(k2<z)
               continue;
           }

         if(u1!=1.0)
            v=beta*MathLog(u1/(1.0-u1));
         else
            v=0.0;
         w=a1*MathExp(v);

         if(MathLog(z)<=alpha*(MathLog(alpha/(b1+w))+v)-log4)
            break;
        }
     }

   if(a==a1)
      value=w/(b1+w);
   else
      value=b1/(b1+w);
//---
   return value;
  }
//+------------------------------------------------------------------+
//| Random variate from the Beta distribution                        |
//+------------------------------------------------------------------+
//| The function returns a single random deviate from the Beta       |
//| distribution with parameters a and b.                            |
//|                                                                  |
//| Arguments:                                                       |
//| a           : First shape parameter (a>0)                        |
//| b           : Second shape parameter (b>0)                       |
//| error_code  : Variable for error code                            |
//|                                                                  |
//| Return value:                                                    |
//| The random value with Beta distribution.                         |
//+------------------------------------------------------------------+
double MathRandomBeta(const double a,const double b,int &error_code)
  {
//--- check parameters
   if(!MathIsValidNumber(a) || !MathIsValidNumber(b))
     {
      error_code=ERR_ARGUMENTS_NAN;
      return QNaN;
     }
//--- a and b must be positive
   if(a<=0.0 || b<=0.0)
     {
      error_code=ERR_ARGUMENTS_INVALID;
      return QNaN;
     }

   error_code=ERR_OK;
//--- return beta random value
   return MathRandomBeta(a,b);
  }
//+------------------------------------------------------------------+
//| Random variate from Beta distribution                            |
//+------------------------------------------------------------------+
//| The function generates random variables from Beta distribution   |
//| with parameters a and b.                                         |
//|                                                                  |
//| Arguments:                                                       |
//| a           : First shape parameter (a>0)                        |
//| b           : Second shape parameter (b>0)                       |
//| data_count  : Number of values needed                            |
//| result      : Output array with random values                    |
//|                                                                  |
//| Return value:                                                    |
//| true if successful, otherwise false.                             |
//+------------------------------------------------------------------+
bool MathRandomBeta(const double a,const double b,const int data_count,double &result[])
  {
   if(data_count<=0)
      return false;
//--- check parameters
   if(!MathIsValidNumber(a) || !MathIsValidNumber(b))
      return false;
//--- a and b must be positive
   if(a<=0.0 || b<=0.0)
      return false;

//--- prepare output array and calculate random values
   ArrayResize(result,data_count);
   for(int i=0; i<data_count; i++)
      result[i]=MathRandomBeta(a,b);

   return true;
  }
//+------------------------------------------------------------------+
//| Beta distriburion moments                                        |
//+------------------------------------------------------------------+
//| The function calculates 4 first moments of the Beta distribution |
//| with parameters a and b.                                         |
//|                                                                  |
//| Arguments:                                                       |
//| a          : First shape parameter (a>0)                         |
//| b          : Second shape parameter (b>0)                        |
//| mean       : Variable for mean value (1st moment)                |
//| variance   : Variable for variance value (2nd moment)            |
//| skewness   : Variable for skewness value (3rd moment)            |
//| kurtosis   : Variable for kurtosis value (4th moment)            |
//| error_code : Variable for error code                             |
//|                                                                  |
//| Return value:                                                    |
//| true if moments calculated successfully, otherwise false.        |
//+------------------------------------------------------------------+
bool MathMomentsBeta(const double a,const double b,double &mean,double &variance,double &skewness,double &kurtosis,int &error_code)
  {
//--- initial values
   mean    =QNaN;
   variance=QNaN;
   skewness=QNaN;
   kurtosis=QNaN;
//--- check NaN
   if(!MathIsValidNumber(a) || !MathIsValidNumber(b))
     {
      error_code=ERR_ARGUMENTS_NAN;
      return false;
     }
//--- a and b must be positive
   if(a<=0.0 || b<=0.0)
     {
      error_code=ERR_ARGUMENTS_INVALID;
      return false;
     }

   error_code=ERR_OK;
//--- calculate moments
   mean    =a/(a+b);
   variance=(a*b)/((a+b)*(a+b)*(a+b+1));
   skewness=2*(b-a)*MathSqrt(a+b+1)/(MathSqrt(a*b)*(a+b+2));
   kurtosis=6*(a*a*a+a*a*(1-2*b)+b*b*(1+b)-2*a*b*(2+b))/(a*b*(a+b+2)*(a+b+3));
//--- successful
   return true;
  }
//+------------------------------------------------------------------+
