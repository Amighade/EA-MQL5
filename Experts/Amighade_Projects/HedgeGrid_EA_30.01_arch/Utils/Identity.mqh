#ifndef IDENTITY_MQH
#define IDENTITY_MQH

int GetSymbolCode(const string sym)
  {
   string s = sym;
   StringToUpper(s);
   if(StringLen(s) > 0 && StringGetCharacter(s, StringLen(s)-1) == '+')
      s = StringSubstr(s, 0, StringLen(s)-1);

   int code = 0;
   for(int i = 0; i < StringLen(s); i++)
      code += StringGetCharacter(s, i);

   return 100 + (code % 900);
  }

int GenerateMagicNumber()
  {
   return GetSymbolCode(_Symbol) * 100000 + (int)_Period;
  }

#endif
