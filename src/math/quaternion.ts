export class Quaternion 
{
    private _onChangeCallback: VoidFunction;

    public constructor(public _x = 0, public _y = 0, public _z = 0, public _w = 1) {
		this._onChangeCallback = () => { };
	}

    public _onChange( callback:VoidFunction ) {

		this._onChangeCallback = callback;

		return this;

	}
}