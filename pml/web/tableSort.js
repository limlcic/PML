//This is a javascript to sort the table.
var Class={
	create:function(){
		return function(){
			this.init.apply(this,arguments)
			}
		}
	}
function each(o,fn){
	for(var j=0,len=o.length;j<len;j++){
		fn(o[j],j)
		}
	}

Function.prototype.bind=function(){
	var method=this;
	var args=Array.prototype.slice.call(arguments);
	var object=args.shift();
	return function(){
		return method.apply(object,args.concat(Array.prototype.slice.call(arguments)))
		}
	}	
function $(elem,elem2){
	var arr=[];
	typeof elem=='string' ?arr.push(document.getElementById(elem)):arr.push(elem);
	elem2&&arr.push(arr[0].getElementsByTagName(elem2));
	(arr.length>1)&&(typeof elem=='object') &&(arr.shift());
	return arr.length!=2?arr[0]:arr[1];
	}
	
var tableListSort=Class.create()
tableListSort.prototype={
	init:function(tables,options){
		this.table=$(tables);
		this.th=$($(this.table,'thead')[0],'th');
		this.tbody=$(this.table,'tbody')[0];
		this.Row=$(this.tbody,'tr'); 
		this.rowArr=[];
		this.Index=null;
		this.options=options||{};
		this.finish=this.options.fn||function(){};
		this.dataIndex=Math.abs(this.options.data)||null;
		this.file=Math.abs(this.options.fileType)||null;
		each(this.Row,function(o){this.rowArr.push(o)}.bind(this));
		for(var i=0;this.th.length>i;i++){
			this.th[i].onclick=this.Sort.bind(this,i)
			this.th[i].style.cursor='pointer';
			}
		this.re=/([-]{0,1}[0-9.]{1,})/g;
		this.dataIndex&&subData(this.Row,this.dataIndex,this.Row.length);
		},

	Sort:function(num){
		
		(this.Index!=null&&this.Index!=num)&&this.th[this.Index].setAttribute('sorted','');
		this.th[num].getAttribute('sorted')!='ed'?
		this.rowArr.sort(this.naturalSort.bind(this,num)):this.rowArr.reverse();
		
		var frag=document.createDocumentFragment();
		each(this.rowArr,function(o){frag.appendChild(o)});
		this.tbody.appendChild(frag);
		this.th[num].setAttribute('sorted','ed');
		
		this.finish(num);
		this.Index=num;
		},
	naturalSort:function (num,a, b) {
	
		var a=this.dataIndex!=num?a.cells[num].innerHTML:a.cells[num].getAttribute('data'),
		    b=this.dataIndex!=num?b.cells[num].innerHTML:b.cells[num].getAttribute('data');
	
        var x = a.toString().toLowerCase() || '', y = b.toString().toLowerCase() || '',
                nC = String.fromCharCode(0),
                xN = x.replace(this.re, nC + '$1' + nC).split(nC),
                yN = y.replace(this.re, nC + '$1' + nC).split(nC),
                xD = (new Date(x)).getTime(), yD = (new Date(y)).getTime()
				xN = this.file!=num?xN:xN.reverse(),
				yN = this.file!=num?yN:yN.reverse()
				;
        if ( xD && yD && xD < yD )
                return -1;
        else if ( xD && yD && xD > yD )
                return 1;
        for ( var cLoc=0, numS = Math.max( xN.length, yN.length ); cLoc < numS; cLoc++ )
                if ( ( parseFloat( xN[cLoc] ) || xN[cLoc] ) < ( parseFloat( yN[cLoc] ) || yN[cLoc] ) )
			
                        return -1;
                else if ( ( parseFloat( xN[cLoc] ) || xN[cLoc] ) > ( parseFloat( yN[cLoc] ) || yN[cLoc] ) )
                        return 1;
        return 0;
		}
	
	}       
function subData(o,i,len){
		for(var j=0;len>j;j++){
			if(o[j].cells[i].innerHTML.substring(o[j].cells[i].innerHTML.lastIndexOf('KB')).toLowerCase()=='kb'){
				o[j].cells[i].setAttribute('data',parseFloat(o[j].cells[i].innerHTML)*1024);
				}
			if(o[j].cells[i].innerHTML.substring(o[j].cells[i].innerHTML.lastIndexOf('MB')).toLowerCase()=='mb'){
				o[j].cells[i].setAttribute('data',parseFloat(o[j].cells[i].innerHTML)*1000000);
				}	
	   else if(o[j].cells[i].innerHTML.substring(o[j].cells[i].innerHTML.lastIndexOf('GB')).toLowerCase()=='gb'){
				o[j].cells[i].setAttribute('data',parseFloat(o[j].cells[i].innerHTML)*1000000000);
				}	
		  }
		}

window.onload=function(){
	function fini(num){
		table.th[num].className=
		table.th[num].className=='selectUp'?
		'selectDown':'selectUp';
		
		each(table.Row,function(o){
								o.cells[num].className='highLight';
								if(table.Index!=null&&table.Index!=num){
								o.cells[table.Index].className='';
								}
								});
		if(table.Index!=null&&table.Index!=num){
			table.th[table.Index].className='';
			}
		}

var table=new tableListSort($('tb'),{fn:fini})
	}	

