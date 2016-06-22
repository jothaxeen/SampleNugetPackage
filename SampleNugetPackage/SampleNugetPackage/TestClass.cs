using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;

namespace SampleNugetPackage
{
    public class TestClass
    {
        public string Test(bool ForceFail = false)
        {
            if (ForceFail)
            {
                throw new Exception("Throw exception for testing.");
            }
            else
            {
                return "Success";
            }
        }
    }
}
