using System;
using System.Threading;
using System.Management.Automation;
using System.Collections.ObjectModel;
using System.Collections.Generic;
using System.Management.Automation.Runspaces;

using System.Security.Cryptography.X509Certificates;
using System.Net.Security;

public class ScriptBlockInvoker
{
    public ScriptBlock ScriptBlock { get; private set; }
    public Dictionary<string, ScriptBlock> FunctionsToDefine { get; private set; }
    public List<PSVariable> VariablesToDefine { get; private set; }
    public object[] Args { get; private set; }

    Collection<PSObject> _ReturnValue;
    public Collection<PSObject> ReturnValue {
        get
        {
            if (!IsComplete)
            {
                throw new System.InvalidOperationException("Cannot access ReturnValue until Invoke() completes.");
            }
            return _ReturnValue;
        }
        private set { _ReturnValue = value; }
    }
    public bool IsComplete { get; private set; }
    public bool IsRunning { get; private set; }

    public void Init()
    {
        IsComplete = false;
        IsRunning = false;
    }

    public ScriptBlockInvoker(ScriptBlock scriptBlock)
    {
        Init();
        ScriptBlock = scriptBlock;
        VariablesToDefine = new List<PSVariable>();
        FunctionsToDefine = new Dictionary<string, ScriptBlock>();
    }

    public ScriptBlockInvoker(
        ScriptBlock scriptBlock,
        Dictionary<string, ScriptBlock> functionsToDefine,
        List<PSVariable> variablesToDefine,
        object[] args
    ) : this(scriptBlock)
    {
        FunctionsToDefine = functionsToDefine;
        VariablesToDefine = variablesToDefine;
        Args = args;
    }

    public void Invoke()
    {
        IsComplete = false;
        ReturnValue = null;
        IsRunning = true;
        if (Runspace.DefaultRunspace == null)
        {
            Console.WriteLine("No default runspace.  Creating one.");
            Runspace.DefaultRunspace = RunspaceFactory.CreateRunspace();
        }
        ReturnValue = ScriptBlock.InvokeWithContext(
            FunctionsToDefine,
            VariablesToDefine,
            Args
        );
        IsComplete = true;
        IsRunning = false;
    }

    public Collection<PSObject> InvokeReturn()
    {
        Invoke();
        return ReturnValue;
    }

    public Func<Collection<PSObject>> InvokeFuncReturn
    {
        get { return InvokeReturn; }
    }

    public Action InvokeAction
    {
        get { return Invoke; }
    }

    public ThreadStart InvokeThreadStart
    {
        get { return Invoke; }
    }
}

public class CertificateValidator : ScriptBlockInvoker
{
    public CertificateValidator(ScriptBlock sb) : base(sb) { }

    public CertificateValidator(
        ScriptBlock scriptBlock,
        Dictionary<string, ScriptBlock> functionsToDefine,
        List<PSVariable> variablesToDefine,
        object[] args
    ) : base(scriptBlock,functionsToDefine,variablesToDefine,args)
    {}

    public bool CertValidationCallback(
        object sender,
        X509Certificate certificate,
        X509Chain chain,
        SslPolicyErrors sslPolicyErrors)
    {
        PSObject args = new PSObject();

        args.Members.Add(new PSNoteProperty("sender", sender));
        args.Members.Add(new PSNoteProperty("certificate", certificate));
        args.Members.Add(new PSNoteProperty("chain", chain));
        args.Members.Add(new PSNoteProperty("sslPolicyErrors", sslPolicyErrors));

        VariablesToDefine.Add(new PSVariable("_", args));

        Invoke();

        if ( ReturnValue.Count == 0)
        {
            return false;
        }

        foreach (var item in ReturnValue)
        {
            dynamic d = item.BaseObject;
            if (!d)
            {
                return false;
            }
        }
        return true;
    }

    public RemoteCertificateValidationCallback Delegate
    {
        get { return CertValidationCallback; }
    }
}