class Dict extends Object;

struct DictKeyValue
{
	var Object Key;
	var Object Value;
};

var PrivateWrite array<DictKeyValue> KeyValues;

function bool Add(Object Key, Object Value)
{
	local int i;
	local DictKeyValue kv;
	
	for (i = 0; i < self.KeyValues.Length; ++i) 
	{
		kv = self.KeyValues[i];
		
		if (kv.Key == Key)
			return false;
	}
	
	kv.Key   = Key;
	kv.Value = Value;
	
	self.KeyValues.AddItem(kv);
	
	return true;
}

function bool Remove(Object Key)
{
    local int i;
    local DictKeyValue kv;
    
    for (i = 0; i < self.KeyValues.Length; ++i) 
    {
        kv = self.KeyValues[i];
        
        if (kv.Key == Key)
        {
            self.KeyValues.Remove(i, 1);
            return true;   
        }
    }
    
    return false;
}

function bool GetValue(Object Key, out Object Value)
{
    local int i;
    local DictKeyValue kv;
    
    for (i = 0; i < self.KeyValues.Length; ++i) 
    {
        kv = self.KeyValues[i];
        
        if (kv.Key == Key)
        {
            Value = kv.Value;
            return true;
        }
    }
    
    return false;
}

function bool ContainsKey(Object Key)
{
    local Object Value;
    
    return self.GetValue(Key, Value);
}

function bool TryGetValue(Object Key, out Object Value)
{
    local int i;
    local DictKeyValue kv;
    
    for (i = 0; i < self.KeyValues.Length; ++i) 
    {
        kv = self.KeyValues[i];
        
        if (kv.Key == Key)
        {
            Value = kv.Value;
            return true;
        }
    }
    
    return false;
}

function Clear()
{
    self.KeyValues.Length = 0;
}

defaultproperties
{
}
